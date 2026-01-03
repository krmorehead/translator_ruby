import { useRef } from "react";

// FilePathSelector component - combines text input with native file browser
// Follows OOP principles with clean separation of concerns
function FilePathSelector({ value, onChange, label, placeholder, disabled }) {
  const fileInputRef = useRef(null);

  const handleInputChange = (e) => {
    onChange(e.target.value);
  };

  const handleBrowseClick = () => {
    if (fileInputRef.current) {
      fileInputRef.current.click();
    }
  };

  const handleFileSelect = (e) => {
    const files = e.target.files;
    if (files && files.length > 0) {
      // For directory selection with webkitdirectory, get the directory path
      // For single file, get the file path
      const file = files[0];
      
      // Use webkitRelativePath if available (directory selection)
      // Otherwise use the file name (file selection)
      const path = file.webkitRelativePath
        ? file.webkitRelativePath.split("/").slice(0, -1).join("/")
        : file.name;
      
      // In browser environment, we can't get absolute paths for security reasons
      // So we'll use the relative path or just the directory name
      // The user will need to manually adjust to absolute path or we'll handle it on backend
      onChange(path || file.name);
    }
  };

  return (
    <div className="file-path-selector">
      {label && (
        <label htmlFor="path-input" className="file-path-label">
          {label}
        </label>
      )}
      <div className="file-path-input-group">
        <input
          id="path-input"
          type="text"
          value={value}
          onChange={handleInputChange}
          placeholder={placeholder || "/path/to/directory"}
          disabled={disabled}
          className="file-path-text-input"
        />
        <button
          type="button"
          onClick={handleBrowseClick}
          disabled={disabled}
          className="file-path-browse-button"
        >
          Browse
        </button>
        <input
          ref={fileInputRef}
          type="file"
          webkitdirectory="true"
          directory="true"
          multiple
          onChange={handleFileSelect}
          style={{ display: "none" }}
          aria-label="Browse for directory"
        />
      </div>
    </div>
  );
}

export default FilePathSelector;


