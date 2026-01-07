import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useIDEActions } from '../useIDEActions';
import { useAgentStore } from '../../../store/agentStore';
import { useCheckpointStore } from '../../../store/checkpointStore';

describe('useIDEActions', () => {
  let initialAgentState;
  let initialCheckpointState;

  beforeEach(() => {
    vi.clearAllMocks();
    
    // Capture initial states
    initialAgentState = useAgentStore.getState();
    initialCheckpointState = useCheckpointStore.getState();
    
    // Set up test state with spy functions
    useAgentStore.setState({
      mode: 'daedalus',
      projectPath: '/test/project',
      initializeSession: vi.fn(),
      setMode: vi.fn(),
      setProjectPath: vi.fn(),
      loadFileTree: vi.fn(),
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

  it('returns session actions', () => {
    const { result } = renderHook(() => useIDEActions());
    expect(result.current.session.initialize).toBeDefined();
  });

  it('returns agent actions', () => {
    const { result } = renderHook(() => useIDEActions());
    expect(result.current.agent.changeMode).toBeDefined();
  });

  it('returns project actions', () => {
    const { result } = renderHook(() => useIDEActions());
    expect(result.current.project.setPath).toBeDefined();
    expect(result.current.project.loadFileTree).toBeDefined();
  });

  it('returns file actions', () => {
    const { result } = renderHook(() => useIDEActions());
    expect(result.current.file.select).toBeDefined();
  });

  it('returns approval actions', () => {
    const { result } = renderHook(() => useIDEActions());
    expect(result.current.approval.approve).toBeDefined();
    expect(result.current.approval.reject).toBeDefined();
    expect(result.current.approval.close).toBeDefined();
  });

  it('calls initializeSession with mode', async () => {
    const initializeSpy = vi.fn();
    useAgentStore.setState({
      initializeSession: initializeSpy,
    });
    
    const { result } = renderHook(() => useIDEActions());
    await act(async () => {
      await result.current.session.initialize();
    });
    expect(initializeSpy).toHaveBeenCalledWith('daedalus');
  });

  it('calls setMode when changeMode called', () => {
    const setModeSpy = vi.fn();
    useAgentStore.setState({
      setMode: setModeSpy,
    });
    
    const { result } = renderHook(() => useIDEActions());
    act(() => {
      result.current.agent.changeMode('sisyphus');
    });
    expect(setModeSpy).toHaveBeenCalledWith('sisyphus');
  });

  it('calls setProjectPath when setPath called', () => {
    const setProjectPathSpy = vi.fn();
    useAgentStore.setState({
      setProjectPath: setProjectPathSpy,
    });
    
    const { result } = renderHook(() => useIDEActions());
    act(() => {
      result.current.project.setPath('/new/path');
    });
    expect(setProjectPathSpy).toHaveBeenCalledWith('/new/path');
  });

  it('calls loadFileTree and setRepositoryPath when loadFileTree called', () => {
    const loadFileTreeSpy = vi.fn();
    const setRepositoryPathSpy = vi.fn();
    
    useAgentStore.setState({
      loadFileTree: loadFileTreeSpy,
      projectPath: '/test/project',
    });
    
    useCheckpointStore.setState({
      setRepositoryPath: setRepositoryPathSpy,
    });
    
    const { result } = renderHook(() => useIDEActions());
    act(() => {
      result.current.project.loadFileTree();
    });
    expect(loadFileTreeSpy).toHaveBeenCalledWith('/test/project');
    expect(setRepositoryPathSpy).toHaveBeenCalledWith('/test/project');
  });

  it('does not call loadFileTree when projectPath is empty', () => {
    const loadFileTreeSpy = vi.fn();
    useAgentStore.setState({
      loadFileTree: loadFileTreeSpy,
      projectPath: '',
    });
    
    const { result } = renderHook(() => useIDEActions());
    act(() => {
      result.current.project.loadFileTree();
    });
    expect(loadFileTreeSpy).not.toHaveBeenCalled();
  });

  it('calls readFile when file.select called', () => {
    const readFileSpy = vi.fn();
    useAgentStore.setState({
      readFile: readFileSpy,
    });
    
    const { result } = renderHook(() => useIDEActions());
    act(() => {
      result.current.file.select('/test/file.js');
    });
    expect(readFileSpy).toHaveBeenCalledWith('/test/file.js');
  });

  it('calls approveRequest when approval.approve called', async () => {
    const approveRequestSpy = vi.fn();
    useAgentStore.setState({
      approveRequest: approveRequestSpy,
    });
    
    const { result } = renderHook(() => useIDEActions());
    await act(async () => {
      await result.current.approval.approve('request-123');
    });
    expect(approveRequestSpy).toHaveBeenCalledWith('request-123');
  });

  it('calls rejectRequest when approval.reject called', async () => {
    const rejectRequestSpy = vi.fn();
    useAgentStore.setState({
      rejectRequest: rejectRequestSpy,
    });
    
    const { result } = renderHook(() => useIDEActions());
    await act(async () => {
      await result.current.approval.reject('request-123');
    });
    expect(rejectRequestSpy).toHaveBeenCalledWith('request-123');
  });

  it('calls clearApproval when approval.close called', () => {
    const clearApprovalSpy = vi.fn();
    useAgentStore.setState({
      clearApproval: clearApprovalSpy,
    });
    
    const { result } = renderHook(() => useIDEActions());
    act(() => {
      result.current.approval.close();
    });
    expect(clearApprovalSpy).toHaveBeenCalled();
  });

  it('handles errors in session.initialize', async () => {
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});
    const initializeSpy = vi.fn().mockRejectedValue(new Error('Init failed'));
    useAgentStore.setState({
      initializeSession: initializeSpy,
    });
    
    const { result } = renderHook(() => useIDEActions());
    await expect(async () => {
      await act(async () => {
        await result.current.session.initialize();
      });
    }).rejects.toThrow('Init failed');
    
    expect(consoleError).toHaveBeenCalled();
    consoleError.mockRestore();
  });
});
