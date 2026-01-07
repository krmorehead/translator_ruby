import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { renderHook } from '@testing-library/react';
import { useIDEState } from '../useIDEState';
import { useAgentStore } from '../../../store/agentStore';

describe('useIDEState', () => {
  let initialState;

  beforeEach(() => {
    // Capture initial state
    initialState = useAgentStore.getState();
    
    // Set up test state
    useAgentStore.setState({
      currentSessionId: 'test-session-123',
      mode: 'daedalus',
      projectPath: '/test/project',
      sisyphus: {
        ...initialState.sisyphus,
        selectedFile: '/test/file.js',
        fileContent: 'console.log("test");',
        pendingApproval: { id: 'approval-1' },
        approvalLoading: false,
      },
    });
  });

  afterEach(() => {
    // Restore initial state
    useAgentStore.setState(initialState);
  });

  it('returns session state', () => {
    const { result } = renderHook(() => useIDEState());
    expect(result.current.session).toEqual({
      id: 'test-session-123',
      isActive: true,
    });
  });

  it('returns agent state', () => {
    const { result } = renderHook(() => useIDEState());
    expect(result.current.agent).toEqual({
      mode: 'daedalus',
    });
  });

  it('returns project state', () => {
    const { result } = renderHook(() => useIDEState());
    expect(result.current.project).toEqual({
      path: '/test/project',
      isLoaded: true,
    });
  });

  it('returns file state', () => {
    const { result } = renderHook(() => useIDEState());
    expect(result.current.file).toEqual({
      selected: '/test/file.js',
      content: 'console.log("test");',
    });
  });

  it('returns approval state', () => {
    const { result } = renderHook(() => useIDEState());
    expect(result.current.approval).toEqual({
      pending: { id: 'approval-1' },
      loading: false,
      isVisible: true,
    });
  });

  it('marks session as inactive when no sessionId', () => {
    useAgentStore.setState({
      currentSessionId: null,
    });
    
    const { result } = renderHook(() => useIDEState());
    expect(result.current.session.isActive).toBe(false);
  });

  it('marks project as not loaded when no projectPath', () => {
    useAgentStore.setState({
      projectPath: '',
    });
    
    const { result } = renderHook(() => useIDEState());
    expect(result.current.project.isLoaded).toBe(false);
  });

  it('marks approval as not visible when no pending approval', () => {
    useAgentStore.setState({
      sisyphus: {
        ...useAgentStore.getState().sisyphus,
        pendingApproval: null,
      },
    });
    
    const { result } = renderHook(() => useIDEState());
    expect(result.current.approval.isVisible).toBe(false);
  });
});
