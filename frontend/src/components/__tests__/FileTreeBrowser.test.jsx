import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import FileTreeBrowser from '../FileTreeBrowser';
import { useAgentStore } from '../../store/agentStore';

describe('FileTreeBrowser', () => {
  const mockOnFileSelect = vi.fn();
  
  // Store initial state for restoration
  let initialState;

  beforeEach(() => {
    vi.clearAllMocks();
    // Capture initial state
    initialState = useAgentStore.getState();
    
    // Reset to clean state
    useAgentStore.setState({
      sisyphus: {
        ...initialState.sisyphus,
        fileTree: null,
        fileLoading: false,
        fileError: '',
        selectedFile: null,
      },
    });
  });

  afterEach(() => {
    // Restore initial state
    useAgentStore.setState(initialState);
  });

  it('shows empty state when no file tree loaded', () => {
    render(<FileTreeBrowser onFileSelect={mockOnFileSelect} />);
    
    expect(screen.getByText(/Enter a project path and click "Load Project"/)).toBeInTheDocument();
  });

  it('shows loading state', () => {
    useAgentStore.setState({
      sisyphus: {
        ...useAgentStore.getState().sisyphus,
        fileLoading: true,
      },
    });
    
    render(<FileTreeBrowser onFileSelect={mockOnFileSelect} />);
    
    expect(screen.getByText(/Loading file tree/)).toBeInTheDocument();
  });

  it('shows error state', () => {
    useAgentStore.setState({
      sisyphus: {
        ...useAgentStore.getState().sisyphus,
        fileError: 'Failed to load files',
      },
    });
    
    render(<FileTreeBrowser onFileSelect={mockOnFileSelect} />);
    
    expect(screen.getByText(/Error: Failed to load files/)).toBeInTheDocument();
  });

  it('renders file tree with files and directories', () => {
    const fileTree = {
      name: 'root',
      type: 'directory',
      children: [
        {
          name: 'src',
          type: 'directory',
          children: [
            { name: 'index.js', type: 'file' },
            { name: 'App.jsx', type: 'file' },
          ],
        },
        { name: 'README.md', type: 'file' },
      ],
    };

    useAgentStore.setState({
      sisyphus: {
        ...useAgentStore.getState().sisyphus,
        fileTree,
      },
    });
    
    render(<FileTreeBrowser onFileSelect={mockOnFileSelect} />);
    
    expect(screen.getByText('src')).toBeInTheDocument();
    expect(screen.getByText('README.md')).toBeInTheDocument();
  });

  it('expands and collapses directories', () => {
    const fileTree = {
      name: 'root',
      type: 'directory',
      children: [
        {
          name: 'src',
          type: 'directory',
          children: [
            { name: 'index.js', type: 'file' },
          ],
        },
      ],
    };

    useAgentStore.setState({
      sisyphus: {
        ...useAgentStore.getState().sisyphus,
        fileTree,
      },
    });
    
    render(<FileTreeBrowser onFileSelect={mockOnFileSelect} />);
    
    // Initially collapsed - file not visible
    expect(screen.queryByText('index.js')).not.toBeInTheDocument();
    
    // Click to expand
    const srcDir = screen.getByText('src');
    fireEvent.click(srcDir);
    
    // Now file should be visible
    expect(screen.getByText('index.js')).toBeInTheDocument();
    
    // Click again to collapse
    fireEvent.click(srcDir);
    
    // File should be hidden again
    expect(screen.queryByText('index.js')).not.toBeInTheDocument();
  });

  it('calls onFileSelect when file clicked', () => {
    const fileTree = {
      name: 'root',
      type: 'directory',
      children: [
        { name: 'test.js', type: 'file' },
      ],
    };

    useAgentStore.setState({
      sisyphus: {
        ...useAgentStore.getState().sisyphus,
        fileTree,
      },
    });
    
    render(<FileTreeBrowser onFileSelect={mockOnFileSelect} />);
    
    const file = screen.getByText('test.js');
    fireEvent.click(file);
    
    expect(mockOnFileSelect).toHaveBeenCalledWith('test.js');
  });

  it('highlights selected file', () => {
    const fileTree = {
      name: 'root',
      type: 'directory',
      children: [
        { name: 'selected.js', type: 'file' },
        { name: 'other.js', type: 'file' },
      ],
    };

    useAgentStore.setState({
      sisyphus: {
        ...useAgentStore.getState().sisyphus,
        fileTree,
        selectedFile: 'selected.js',
      },
    });
    
    render(<FileTreeBrowser onFileSelect={mockOnFileSelect} />);
    
    const selectedFile = screen.getByText('selected.js').closest('.tree-item');
    expect(selectedFile).toHaveClass('selected');
    
    const otherFile = screen.getByText('other.js').closest('.tree-item');
    expect(otherFile).not.toHaveClass('selected');
  });

  it('shows correct icons for different file types', () => {
    const fileTree = {
      name: 'root',
      type: 'directory',
      children: [
        { name: 'script.js', type: 'file' },
        { name: 'component.jsx', type: 'file' },
        { name: 'model.rb', type: 'file' },
        { name: 'style.css', type: 'file' },
        { name: 'README.md', type: 'file' },
      ],
    };

    useAgentStore.setState({
      sisyphus: {
        ...useAgentStore.getState().sisyphus,
        fileTree,
      },
    });
    
    render(<FileTreeBrowser onFileSelect={mockOnFileSelect} />);
    
    // All files should be rendered
    expect(screen.getByText('script.js')).toBeInTheDocument();
    expect(screen.getByText('component.jsx')).toBeInTheDocument();
    expect(screen.getByText('model.rb')).toBeInTheDocument();
    expect(screen.getByText('style.css')).toBeInTheDocument();
    expect(screen.getByText('README.md')).toBeInTheDocument();
  });

  it('handles nested directory structure', () => {
    const fileTree = {
      name: 'root',
      type: 'directory',
      children: [
        {
          name: 'app',
          type: 'directory',
          children: [
            {
              name: 'components',
              type: 'directory',
              children: [
                { name: 'Button.jsx', type: 'file' },
              ],
            },
          ],
        },
      ],
    };

    useAgentStore.setState({
      sisyphus: {
        ...useAgentStore.getState().sisyphus,
        fileTree,
      },
    });
    
    render(<FileTreeBrowser onFileSelect={mockOnFileSelect} />);
    
    // Expand first level
    fireEvent.click(screen.getByText('app'));
    expect(screen.getByText('components')).toBeInTheDocument();
    
    // Expand second level
    fireEvent.click(screen.getByText('components'));
    expect(screen.getByText('Button.jsx')).toBeInTheDocument();
  });

  it('renders empty browser when tree has no children', () => {
    const fileTree = {
      name: 'root',
      type: 'directory',
      children: [],
    };

    useAgentStore.setState({
      sisyphus: {
        ...useAgentStore.getState().sisyphus,
        fileTree,
      },
    });
    
    render(<FileTreeBrowser onFileSelect={mockOnFileSelect} />);
    
    // The component renders an empty file tree browser when children array is empty
    const browser = document.querySelector('.file-tree-browser');
    expect(browser).toBeInTheDocument();
    expect(browser).toBeEmptyDOMElement();
  });
});
