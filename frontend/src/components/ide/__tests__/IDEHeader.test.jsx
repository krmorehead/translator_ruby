import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { IDEHeader } from '../IDEHeader';

describe('IDEHeader', () => {
  const mockProps = {
    sessionId: null,
    projectPath: '',
    onProjectPathChange: vi.fn(),
    onLoadProject: vi.fn(),
    onBrowseDirectory: vi.fn(),
    onInitializeSession: vi.fn(),
    onOpenPreferences: vi.fn(),
    showInitButton: true,
  };

  it('renders IDE title', () => {
    render(<IDEHeader {...mockProps} />);
    expect(screen.getByText('🛠️ IDE')).toBeInTheDocument();
  });

  it('shows session badge when session exists', () => {
    render(<IDEHeader {...mockProps} sessionId="test-session-12345" />);
    expect(screen.getByText(/Session: test-ses/)).toBeInTheDocument();
  });

  it('does not show session badge when no session', () => {
    render(<IDEHeader {...mockProps} />);
    expect(screen.queryByText(/Session:/)).not.toBeInTheDocument();
  });

  it('renders project path input', () => {
    render(<IDEHeader {...mockProps} projectPath="/test/path" />);
    const input = screen.getByPlaceholderText('Enter project path...');
    expect(input).toHaveValue('/test/path');
  });

  it('calls onProjectPathChange when input changes', () => {
    render(<IDEHeader {...mockProps} />);
    const input = screen.getByPlaceholderText('Enter project path...');
    fireEvent.change(input, { target: { value: '/new/path' } });
    expect(mockProps.onProjectPathChange).toHaveBeenCalledWith('/new/path');
  });

  it('calls onLoadProject when Load Project clicked', () => {
    render(<IDEHeader {...mockProps} />);
    const button = screen.getByText('Load Project');
    fireEvent.click(button);
    expect(mockProps.onLoadProject).toHaveBeenCalled();
  });

  it('shows Initialize Session button when showInitButton is true', () => {
    render(<IDEHeader {...mockProps} showInitButton={true} />);
    expect(screen.getByText('Initialize Session')).toBeInTheDocument();
  });

  it('hides Initialize Session button when showInitButton is false', () => {
    render(<IDEHeader {...mockProps} showInitButton={false} />);
    expect(screen.queryByText('Initialize Session')).not.toBeInTheDocument();
  });

  it('calls onInitializeSession when Initialize Session clicked', () => {
    render(<IDEHeader {...mockProps} />);
    const button = screen.getByText('Initialize Session');
    fireEvent.click(button);
    expect(mockProps.onInitializeSession).toHaveBeenCalled();
  });

  it('calls onOpenPreferences when preferences button clicked', () => {
    render(<IDEHeader {...mockProps} />);
    const button = screen.getByText('👤');
    fireEvent.click(button);
    expect(mockProps.onOpenPreferences).toHaveBeenCalled();
  });

  it('renders Browse button', () => {
    render(<IDEHeader {...mockProps} />);
    expect(screen.getByText('📁 Browse')).toBeInTheDocument();
  });

  it('calls onBrowseDirectory when Browse button clicked', () => {
    render(<IDEHeader {...mockProps} />);
    const button = screen.getByText('📁 Browse');
    fireEvent.click(button);
    expect(mockProps.onBrowseDirectory).toHaveBeenCalled();
  });
});

