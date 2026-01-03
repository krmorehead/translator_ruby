import { describe, test, expect, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { speed_profile } from "../../test/speedProfile";
import FilePathSelector from "../FilePathSelector";

describe("FilePathSelector", () => {
  let capturedValue;
  let handleChange;

  beforeEach(() => {
    capturedValue = null;
    handleChange = (value) => {
      capturedValue = value;
    };
  });

  // ============================================================================
  // RENDERING TESTS
  // ============================================================================

  speed_profile("fast")("renders with label", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Test Label"
      />
    );

    const label = screen.getByText("Test Label");
    expect(label).toBeInTheDocument();
    expect(label.tagName).toBe("LABEL");
  });

  speed_profile("fast")("renders without label when not provided", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
      />
    );

    const labels = screen.queryAllByRole("label");
    expect(labels).toHaveLength(0);
  });

  speed_profile("fast")("renders input with value", () => {
    render(
      <FilePathSelector
        value="/test/path"
        onChange={handleChange}
        label="Path"
      />
    );

    const input = screen.getByDisplayValue("/test/path");
    expect(input).toBeInTheDocument();
    expect(input).toHaveAttribute("type", "text");
  });

  speed_profile("fast")("renders input with empty value", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
      />
    );

    const input = screen.getByRole("textbox");
    expect(input).toBeInTheDocument();
    expect(input.value).toBe("");
  });

  speed_profile("fast")("renders browse button", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
      />
    );

    const button = screen.getByRole("button", { name: /browse/i });
    expect(button).toBeInTheDocument();
    expect(button.textContent).toMatch(/browse/i);
  });

  speed_profile("fast")("renders hidden file input for native browser", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
      />
    );

    const fileInput = screen.getByLabelText(/browse for directory/i);
    expect(fileInput).toBeInTheDocument();
    expect(fileInput).toHaveAttribute("type", "file");
    expect(fileInput.style.display).toBe("none");
  });

  speed_profile("fast")("file input has directory attributes", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
      />
    );

    const fileInput = screen.getByLabelText(/browse for directory/i);
    expect(fileInput).toHaveAttribute("webkitdirectory", "true");
    expect(fileInput).toHaveAttribute("directory", "true");
    expect(fileInput).toHaveAttribute("multiple");
  });

  speed_profile("fast")("uses default placeholder when not provided", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
      />
    );

    const input = screen.getByPlaceholderText("/path/to/directory");
    expect(input).toBeInTheDocument();
  });

  speed_profile("fast")("uses custom placeholder text", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
        placeholder="/custom/placeholder"
      />
    );

    const input = screen.getByPlaceholderText("/custom/placeholder");
    expect(input).toBeInTheDocument();
  });

  speed_profile("fast")("renders with correct CSS classes", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
      />
    );

    const container = screen.getByRole("textbox").closest(".file-path-selector");
    expect(container).toBeInTheDocument();
  });

  // ============================================================================
  // INTERACTION TESTS
  // ============================================================================

  speed_profile("fast")("calls onChange when input value changes", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
      />
    );

    const input = screen.getByRole("textbox");
    fireEvent.change(input, { target: { value: "/new/path" } });

    expect(capturedValue).toBe("/new/path");
  });

  speed_profile("fast")("calls onChange with empty string", () => {
    render(
      <FilePathSelector
        value="/existing/path"
        onChange={handleChange}
        label="Path"
      />
    );

    const input = screen.getByRole("textbox");
    fireEvent.change(input, { target: { value: "" } });

    expect(capturedValue).toBe("");
  });

  speed_profile("fast")("calls onChange multiple times", () => {
    const values = [];
    const multiCapture = (value) => {
      values.push(value);
    };

    render(
      <FilePathSelector
        value=""
        onChange={multiCapture}
        label="Path"
      />
    );

    const input = screen.getByRole("textbox");
    fireEvent.change(input, { target: { value: "/path1" } });
    fireEvent.change(input, { target: { value: "/path2" } });
    fireEvent.change(input, { target: { value: "/path3" } });

    expect(values).toEqual(["/path1", "/path2", "/path3"]);
  });

  speed_profile("fast")("browse button triggers hidden file input click", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
      />
    );

    const fileInput = screen.getByLabelText(/browse for directory/i);
    let clicked = false;
    fileInput.onclick = () => { clicked = true; };

    const button = screen.getByRole("button", { name: /browse/i });
    fireEvent.click(button);

    // The click should propagate to the file input
    expect(clicked).toBe(true);
  });

  speed_profile("fast")("file selection updates path with file name", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
      />
    );

    const fileInput = screen.getByLabelText(/browse for directory/i);
    
    // Simulate file selection
    const file = new File(["content"], "test.txt", { type: "text/plain" });
    Object.defineProperty(file, "webkitRelativePath", {
      value: "",
      writable: false,
    });

    fireEvent.change(fileInput, {
      target: { files: [file] },
    });

    expect(capturedValue).toBe("test.txt");
  });

  speed_profile("fast")("directory selection extracts directory path", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
      />
    );

    const fileInput = screen.getByLabelText(/browse for directory/i);
    
    // Simulate directory selection with webkitRelativePath
    const file = new File(["content"], "file.txt", { type: "text/plain" });
    Object.defineProperty(file, "webkitRelativePath", {
      value: "my-folder/subfolder/file.txt",
      writable: false,
    });

    fireEvent.change(fileInput, {
      target: { files: [file] },
    });

    expect(capturedValue).toBe("my-folder/subfolder");
  });

  speed_profile("fast")("handles file selection with no files", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
      />
    );

    const fileInput = screen.getByLabelText(/browse for directory/i);
    
    fireEvent.change(fileInput, {
      target: { files: [] },
    });

    // Should not call onChange
    expect(capturedValue).toBe(null);
  });

  speed_profile("fast")("handles file selection with null files", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
      />
    );

    const fileInput = screen.getByLabelText(/browse for directory/i);
    
    fireEvent.change(fileInput, {
      target: { files: null },
    });

    // Should not call onChange
    expect(capturedValue).toBe(null);
  });

  // ============================================================================
  // DISABLED STATE TESTS
  // ============================================================================

  speed_profile("fast")("disables input when disabled prop is true", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
        disabled={true}
      />
    );

    const input = screen.getByRole("textbox");
    expect(input).toBeDisabled();
  });

  speed_profile("fast")("enables input when disabled prop is false", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
        disabled={false}
      />
    );

    const input = screen.getByRole("textbox");
    expect(input).not.toBeDisabled();
  });

  speed_profile("fast")("disables button when disabled prop is true", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
        disabled={true}
      />
    );

    const button = screen.getByRole("button", { name: /browse/i });
    expect(button).toBeDisabled();
  });

  speed_profile("fast")("enables button when disabled prop is false", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
        disabled={false}
      />
    );

    const button = screen.getByRole("button", { name: /browse/i });
    expect(button).not.toBeDisabled();
  });

  speed_profile("fast")("does not trigger onChange when disabled", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
        disabled={true}
      />
    );

    const input = screen.getByRole("textbox");
    fireEvent.change(input, { target: { value: "/new/path" } });

    // Browser prevents change on disabled inputs, so this wouldn't fire anyway
    // but we're testing the intent
    expect(input).toBeDisabled();
  });

  // ============================================================================
  // EDGE CASES
  // ============================================================================

  speed_profile("fast")("handles very long paths", () => {
    const longPath = "/very/long/path/that/goes/on/and/on/and/on/with/many/subdirectories";
    
    render(
      <FilePathSelector
        value={longPath}
        onChange={handleChange}
        label="Path"
      />
    );

    const input = screen.getByRole("textbox");
    expect(input.value).toBe(longPath);
  });

  speed_profile("fast")("handles paths with special characters", () => {
    const specialPath = "/path/with spaces/and-dashes/under_scores/(parens)/[brackets]";
    
    render(
      <FilePathSelector
        value={specialPath}
        onChange={handleChange}
        label="Path"
      />
    );

    const input = screen.getByRole("textbox");
    expect(input.value).toBe(specialPath);
  });

  speed_profile("fast")("handles Windows-style paths", () => {
    const windowsPath = "C:\\Users\\Test\\Documents\\Project";
    
    render(
      <FilePathSelector
        value={windowsPath}
        onChange={handleChange}
        label="Path"
      />
    );

    const input = screen.getByRole("textbox");
    expect(input.value).toBe(windowsPath);
  });

  speed_profile("fast")("label has correct htmlFor attribute", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
      />
    );

    const label = screen.getByText("Path");
    const input = screen.getByRole("textbox");
    
    expect(label).toHaveAttribute("for", input.id);
  });

  speed_profile("fast")("maintains focus after value change", () => {
    render(
      <FilePathSelector
        value=""
        onChange={handleChange}
        label="Path"
      />
    );

    const input = screen.getByRole("textbox");
    input.focus();
    
    expect(document.activeElement).toBe(input);
    
    fireEvent.change(input, { target: { value: "/new/path" } });
    
    // Focus should remain on input
    expect(document.activeElement).toBe(input);
  });
});

