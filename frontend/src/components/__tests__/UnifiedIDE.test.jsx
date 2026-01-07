import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import UnifiedIDE from '../UnifiedIDE';
import { useAgentStore } from '../../store/agentStore';
import { useCheckpointStore } from '../../store/checkpointStore';

// Mock child components to focus on UnifiedIDE logic
vi.mock('../FileTreeBrowser', () => ({
  default: ({ onFileSelect }) => (
    <div data-testid="file-tree-browser">
      <button onClick={() => onFileSelect('/test/file.js')}>Select File</button>
    </div>
  ),
}));

vi.mock('../CodeEditor', () => ({
  default: ({ filePath, content }) => (
    <div data-testid="code-editor">
      {filePath && <span>File: {filePath}</span>}
      {content && <span>Content: {content}</span>}
    </div>
  ),
}));

vi.mock('../MemoryInspector', () => ({
  default: () => <div data-testid="memory-inspector">Memory</div>,
}));

vi.mock('../ChatPanel', () => ({
  default: () => <div data-testid="chat-panel">Chat</div>,
}));

vi.mock('../ThoughtsPanel', () => ({
  default: () => <div data-testid="thoughts-panel">Thoughts</div>,
}));

vi.mock('../ContextManager', () => ({
  default: () => <div data-testid="context-manager">Context</div>,
}));

vi.mock('../TimelineView', () => ({
  default: () => <div data-testid="timeline-view">Timeline</div>,
}));

vi.mock('../CheckpointManager', () => ({
  default: () => <div data-testid="checkpoint-manager">Checkpoints</div>,
}));

vi.mock('../ConfigurationPanel', () => ({
  default: () => <div data-testid="config-panel">Config</div>,
}));

vi.mock('../UserPreferencesPanel', () => ({
  default: ({ onClose }) => (
    <div data-testid="preferences-panel">
      <button onClick={onClose}>Close</button>
    </div>
  ),
}));

vi.mock('../PersistentContext', () => ({
  default: () => <div data-testid="persistent-context">Context</div>,
}));

vi.mock('../ErrorBoundary', () => ({
  default: ({ children }) => <div>{children}</div>,
}));

vi.mock('../ApprovalModal', () => ({
  default: () => <div data-testid="approval-modal">Approval</div>,
}));

vi.mock('../../hooks/useKeyboardShortcuts.jsx', () => ({
  useKeyboardShortcuts: vi.fn(),
}));

describe('UnifiedIDE', () => {
  let initialAgentState;
  let initialCheckpointState;

  beforeEach(() => {
    vi.clearAllMocks();
    
    // Capture initial states
    initialAgentState = useAgentStore.getState();
    initialCheckpointState = useCheckpointStore.getState();
    
    // Set up clean test state
    useAgentStore.setState({
      currentSessionId: null,
      initializeSession: vi.fn(),
      mode: 'daedalus',
      setMode: vi.fn(),
      projectPath: '',
      setProjectPath: vi.fn(),
      loadFileTree: vi.fn(),
      sisyphus: {
        ...initialAgentState.sisyphus,
        selectedFile: null,
        fileContent: '',
        pendingApproval: null,
        approvalLoading: false,
      },
      readFile: vi.fn(),
      approveRequest: vi.fn(),
      rejectRequest: vi.fn(),
      clearApproval: vi.fn(),
    });
    
    useCheckpointStore.setState({
      setRepositoryPath: vi.fn(),
    });
  });

  afterEach(() => {
    // Restore initial states
    useAgentStore.setState(initialAgentState);
    useCheckpointStore.setState(initialCheckpointState);
  });

  it('renders the three-panel layout', () => {
    render(<UnifiedIDE />);
    
    expect(screen.getByText('🛠️ IDE')).toBeInTheDocument();
    expect(screen.getByText('📁 Files')).toBeInTheDocument();
    expect(screen.getByText('📝 Editor')).toBeInTheDocument();
    expect(screen.getByText('🤖 Agent')).toBeInTheDocument();
  });

  it('shows initialize session button when no session', () => {
    render(<UnifiedIDE />);
    
    const initButton = screen.getByText('Initialize Session');
    expect(initButton).toBeInTheDocument();
  });

  it('calls initializeSession when button clicked', async () => {
    const initializeSpy = vi.fn();
    useAgentStore.setState({
      initializeSession: initializeSpy,
    });
    
    render(<UnifiedIDE />);
    
    const initButton = screen.getByText('Initialize Session');
    fireEvent.click(initButton);
    
    await waitFor(() => {
      expect(initializeSpy).toHaveBeenCalledWith('daedalus');
    });
  });

  it('shows session badge when session exists', () => {
    useAgentStore.setState({
      currentSessionId: 'test-session-123',
    });
    
    render(<UnifiedIDE />);
    
    expect(screen.getByText(/Session: test-ses/)).toBeInTheDocument();
  });

  it('loads file tree when Load Project clicked', () => {
    const loadFileTreeSpy = vi.fn();
    const setRepositoryPathSpy = vi.fn();
    
    useAgentStore.setState({
      projectPath: '/home/user/project',
      loadFileTree: loadFileTreeSpy,
    });
    
    useCheckpointStore.setState({
      setRepositoryPath: setRepositoryPathSpy,
    });
    
    render(<UnifiedIDE />);
    
    const loadButton = screen.getByText('Load Project');
    fireEvent.click(loadButton);
    
    expect(loadFileTreeSpy).toHaveBeenCalledWith('/home/user/project');
    expect(setRepositoryPathSpy).toHaveBeenCalledWith('/home/user/project');
  });

  it('does not load file tree when project path is empty', () => {
    const loadFileTreeSpy = vi.fn();
    useAgentStore.setState({
      projectPath: '',
      loadFileTree: loadFileTreeSpy,
    });
    
    render(<UnifiedIDE />);
    
    const loadButton = screen.getByText('Load Project');
    fireEvent.click(loadButton);
    
    expect(loadFileTreeSpy).not.toHaveBeenCalled();
  });

  it('updates project path on input change', () => {
    const setProjectPathSpy = vi.fn();
    useAgentStore.setState({
      setProjectPath: setProjectPathSpy,
    });
    
    render(<UnifiedIDE />);
    
    const input = screen.getByPlaceholderText('Enter project path...');
    fireEvent.change(input, { target: { value: '/new/path' } });
    
    expect(setProjectPathSpy).toHaveBeenCalledWith('/new/path');
  });

  it('calls readFile when file selected from tree', () => {
    const readFileSpy = vi.fn();
    useAgentStore.setState({
      readFile: readFileSpy,
    });
    
    render(<UnifiedIDE />);
    
    const selectButton = screen.getByText('Select File');
    fireEvent.click(selectButton);
    
    expect(readFileSpy).toHaveBeenCalledWith('/test/file.js');
  });

  it('toggles preferences panel', () => {
    render(<UnifiedIDE />);
    
    const prefsButton = screen.getByText('👤');
    fireEvent.click(prefsButton);
    
    expect(screen.getByTestId('preferences-panel')).toBeInTheDocument();
    
    const closeButton = screen.getByText('Close');
    fireEvent.click(closeButton);
    
    expect(screen.queryByTestId('preferences-panel')).not.toBeInTheDocument();
  });

  it('toggles config modal', () => {
    render(<UnifiedIDE />);
    
    const configButton = screen.getAllByText('⚙️')[0];
    fireEvent.click(configButton);
    
    expect(screen.getByTestId('config-panel')).toBeInTheDocument();
  });

  it('changes agent mode via selector', () => {
    const setModeSpy = vi.fn();
    useAgentStore.setState({
      setMode: setModeSpy,
    });
    
    render(<UnifiedIDE />);
    
    const selector = screen.getByDisplayValue(/Daedalus/);
    fireEvent.change(selector, { target: { value: 'sisyphus' } });
    
    expect(setModeSpy).toHaveBeenCalledWith('sisyphus');
  });

  it('shows tabs when session is active', () => {
    useAgentStore.setState({
      currentSessionId: 'test-session',
    });
    
    render(<UnifiedIDE />);
    
    expect(screen.getByText('💬 Chat')).toBeInTheDocument();
    expect(screen.getByText('💭 Thoughts')).toBeInTheDocument();
    expect(screen.getByText('📁 Context')).toBeInTheDocument();
    expect(screen.getByText('⏱️ Timeline')).toBeInTheDocument();
    expect(screen.getByText('📍 Checkpoints')).toBeInTheDocument();
  });

  it('switches between tabs', () => {
    useAgentStore.setState({
      currentSessionId: 'test-session',
    });
    
    render(<UnifiedIDE />);
    
    // Default is chat
    expect(screen.getByTestId('chat-panel')).toBeInTheDocument();
    
    // Switch to thoughts
    fireEvent.click(screen.getByText('💭 Thoughts'));
    expect(screen.getByTestId('thoughts-panel')).toBeInTheDocument();
    
    // Switch to context
    fireEvent.click(screen.getByText('📁 Context'));
    expect(screen.getByTestId('context-manager')).toBeInTheDocument();
    
    // Switch to timeline
    fireEvent.click(screen.getByText('⏱️ Timeline'));
    expect(screen.getByTestId('timeline-view')).toBeInTheDocument();
    
    // Switch to checkpoints
    fireEvent.click(screen.getByText('📍 Checkpoints'));
    expect(screen.getByTestId('checkpoint-manager')).toBeInTheDocument();
  });

  it('shows persistent context when session active', () => {
    useAgentStore.setState({
      currentSessionId: 'test-session',
    });
    
    render(<UnifiedIDE />);
    
    expect(screen.getByTestId('persistent-context')).toBeInTheDocument();
  });

  it('does not show persistent context when no session', () => {
    render(<UnifiedIDE />);
    
    expect(screen.queryByTestId('persistent-context')).not.toBeInTheDocument();
  });

  it('shows empty state message when no session', () => {
    render(<UnifiedIDE />);
    
    expect(screen.getByText(/Initialize a session to start chatting/)).toBeInTheDocument();
  });

  it('renders Browse button for directory selection', () => {
    render(<UnifiedIDE />);
    
    const browseButton = screen.getByText(/📁 Browse/i);
    expect(browseButton).toBeInTheDocument();
  });

  it('opens directory picker modal when Browse button clicked', () => {
    render(<UnifiedIDE />);
    
    const browseButton = screen.getByText(/📁 Browse/i);
    fireEvent.click(browseButton);

    // Modal should be visible
    expect(screen.getByText(/select project directory/i)).toBeInTheDocument();
  });

  it('closes directory picker modal when cancel clicked', () => {
    render(<UnifiedIDE />);
    
    // Open modal
    const browseButton = screen.getByText(/📁 Browse/i);
    fireEvent.click(browseButton);
    
    expect(screen.getByText(/select project directory/i)).toBeInTheDocument();
    
    // Close modal
    const cancelButton = screen.getByText('Cancel');
    fireEvent.click(cancelButton);
    
    // Modal should be gone
    expect(screen.queryByText(/select project directory/i)).not.toBeInTheDocument();
  });

  it('auto-initializes session when loading project with path', () => {
    const loadFileTreeSpy = vi.fn();
    const initializeSessionSpy = vi.fn();
    const setRepositoryPathSpy = vi.fn();

    useAgentStore.setState({
      projectPath: '/home/user/project',
      currentSessionId: null, // No active session
      loadFileTree: loadFileTreeSpy,
      initializeSession: initializeSessionSpy,
    });

    useCheckpointStore.setState({
      setRepositoryPath: setRepositoryPathSpy,
    });

    render(<UnifiedIDE />);
    
    const loadButton = screen.getByText('Load Project');
    fireEvent.click(loadButton);

    // Should load file tree
    expect(loadFileTreeSpy).toHaveBeenCalledWith('/home/user/project');
    // Should sync checkpoint store
    expect(setRepositoryPathSpy).toHaveBeenCalledWith('/home/user/project');
    // Should auto-initialize session
    expect(initializeSessionSpy).toHaveBeenCalled();
  });

  it('does not auto-initialize session if session already active', () => {
    const loadFileTreeSpy = vi.fn();
    const initializeSessionSpy = vi.fn();

    useAgentStore.setState({
      projectPath: '/home/user/project',
      currentSessionId: 'existing-session', // Active session
      loadFileTree: loadFileTreeSpy,
      initializeSession: initializeSessionSpy,
    });

    render(<UnifiedIDE />);
    
    const loadButton = screen.getByText('Load Project');
    fireEvent.click(loadButton);

    // Should load file tree
    expect(loadFileTreeSpy).toHaveBeenCalled();
    // Should NOT auto-initialize session (already active)
    expect(initializeSessionSpy).not.toHaveBeenCalled();
  });
});
