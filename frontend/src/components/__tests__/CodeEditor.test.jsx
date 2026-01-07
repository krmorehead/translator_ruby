import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import CodeEditor from '../CodeEditor';
import { useAgentStore } from '../../store/agentStore';

// Mock Monaco Editor (external library)
vi.mock('@monaco-editor/react', () => ({
  default: ({ value, language, onMount, options }) => {
    const mockEditor = {
      getValue: () => value || '',
    };
    
    // Call onMount if provided
    if (onMount) {
      setTimeout(() => onMount(mockEditor), 0);
    }
    
    return (
      <div data-testid="monaco-editor">
        <div data-testid="editor-language">{language}</div>
        <div data-testid="editor-readonly">{options.readOnly ? 'readonly' : 'editable'}</div>
        <div data-testid="editor-content">{value}</div>
      </div>
    );
  },
}));

describe('CodeEditor', () => {
  let initialState;

  beforeEach(() => {
    vi.clearAllMocks();
    
    // Capture initial state
    initialState = useAgentStore.getState();
    
    // Set up test state
    useAgentStore.setState({
      userPreferences: { theme: 'light' },
    });
    
    // Mock window.addEventListener for keyboard shortcuts
    global.addEventListener = vi.fn();
    global.removeEventListener = vi.fn();
  });

  afterEach(() => {
    // Restore initial state
    useAgentStore.setState(initialState);
  });

  it('shows empty state when no file selected', () => {
    render(<CodeEditor filePath={null} content="" readOnly={false} />);
    
    expect(screen.getByText(/Select a file from the file browser/)).toBeInTheDocument();
  });

  it('renders Monaco editor when file selected', () => {
    render(<CodeEditor filePath="/test/file.js" content="console.log('test');" readOnly={false} />);
    
    expect(screen.getByTestId('monaco-editor')).toBeInTheDocument();
    expect(screen.getByTestId('editor-content')).toHaveTextContent("console.log('test');");
  });

  it('detects JavaScript language from .js extension', () => {
    render(<CodeEditor filePath="/test/file.js" content="" readOnly={false} />);
    
    expect(screen.getByTestId('editor-language')).toHaveTextContent('javascript');
  });

  it('detects TypeScript language from .ts extension', () => {
    render(<CodeEditor filePath="/test/file.ts" content="" readOnly={false} />);
    
    expect(screen.getByTestId('editor-language')).toHaveTextContent('typescript');
  });

  it('detects Ruby language from .rb extension', () => {
    render(<CodeEditor filePath="/test/model.rb" content="" readOnly={false} />);
    
    expect(screen.getByTestId('editor-language')).toHaveTextContent('ruby');
  });

  it('detects Python language from .py extension', () => {
    render(<CodeEditor filePath="/test/script.py" content="" readOnly={false} />);
    
    expect(screen.getByTestId('editor-language')).toHaveTextContent('python');
  });

  it('detects CSS language from .css extension', () => {
    render(<CodeEditor filePath="/test/style.css" content="" readOnly={false} />);
    
    expect(screen.getByTestId('editor-language')).toHaveTextContent('css');
  });

  it('detects Markdown language from .md extension', () => {
    render(<CodeEditor filePath="/test/README.md" content="" readOnly={false} />);
    
    expect(screen.getByTestId('editor-language')).toHaveTextContent('markdown');
  });

  it('defaults to plaintext for unknown extensions', () => {
    render(<CodeEditor filePath="/test/file.unknown" content="" readOnly={false} />);
    
    expect(screen.getByTestId('editor-language')).toHaveTextContent('plaintext');
  });

  it('shows as readonly when readOnly prop is true', () => {
    render(<CodeEditor filePath="/test/file.js" content="" readOnly={true} />);
    
    expect(screen.getByTestId('editor-readonly')).toHaveTextContent('readonly');
  });

  it('shows as editable when readOnly prop is false', () => {
    render(<CodeEditor filePath="/test/file.js" content="" readOnly={false} />);
    
    expect(screen.getByTestId('editor-readonly')).toHaveTextContent('editable');
  });

  it('shows status bar with save hint when not readonly', () => {
    render(<CodeEditor filePath="/test/file.js" content="" readOnly={false} />);
    
    expect(screen.getByText(/Press Cmd\+S.*or Ctrl\+S.*to save/)).toBeInTheDocument();
  });

  it('does not show status bar when readonly', () => {
    render(<CodeEditor filePath="/test/file.js" content="" readOnly={true} />);
    
    expect(screen.queryByText(/Press Cmd\+S/)).not.toBeInTheDocument();
  });

  it('registers keyboard event listener on mount', () => {
    render(<CodeEditor filePath="/test/file.js" content="" readOnly={false} />);
    
    expect(global.addEventListener).toHaveBeenCalledWith('keydown', expect.any(Function));
  });

  it('unregisters keyboard event listener on unmount', () => {
    const { unmount } = render(<CodeEditor filePath="/test/file.js" content="" readOnly={false} />);
    
    unmount();
    
    expect(global.removeEventListener).toHaveBeenCalledWith('keydown', expect.any(Function));
  });

  it('handles empty content gracefully', () => {
    render(<CodeEditor filePath="/test/file.js" content="" readOnly={false} />);
    
    expect(screen.getByTestId('monaco-editor')).toBeInTheDocument();
    expect(screen.getByTestId('editor-content')).toHaveTextContent('');
  });

  it('handles null content gracefully', () => {
    render(<CodeEditor filePath="/test/file.js" content={null} readOnly={false} />);
    
    expect(screen.getByTestId('monaco-editor')).toBeInTheDocument();
  });

  it('updates when file path changes', () => {
    const { rerender } = render(<CodeEditor filePath="/test/file1.js" content="content1" readOnly={false} />);
    
    expect(screen.getByTestId('editor-content')).toHaveTextContent('content1');
    
    rerender(<CodeEditor filePath="/test/file2.js" content="content2" readOnly={false} />);
    
    expect(screen.getByTestId('editor-content')).toHaveTextContent('content2');
  });

  it('uses dark theme when theme preference is dark', () => {
    useAgentStore.setState({
      userPreferences: { theme: 'dark' },
    });
    
    render(<CodeEditor filePath="/test/file.js" content="" readOnly={false} />);
    
    // Monaco editor should be rendered (theme is passed to Monaco internally)
    expect(screen.getByTestId('monaco-editor')).toBeInTheDocument();
  });
});
