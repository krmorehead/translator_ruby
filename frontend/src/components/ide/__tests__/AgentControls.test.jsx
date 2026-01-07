import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { AgentControls } from '../AgentControls';

describe('AgentControls', () => {
  const mockProps = {
    mode: 'daedalus',
    onModeChange: vi.fn(),
    onOpenConfig: vi.fn(),
  };

  it('renders agent selector with current mode', () => {
    render(<AgentControls {...mockProps} />);
    const selector = screen.getByDisplayValue(/Daedalus/);
    expect(selector).toBeInTheDocument();
  });

  it('shows all agent options', () => {
    render(<AgentControls {...mockProps} />);
    const selector = screen.getByRole('combobox');
    expect(selector).toContainHTML('Daedalus (Planning)');
    expect(selector).toContainHTML('Sisyphus (Execution)');
    expect(selector).toContainHTML('Researcher (Analysis)');
  });

  it('calls onModeChange when mode selected', () => {
    render(<AgentControls {...mockProps} />);
    const selector = screen.getByRole('combobox');
    fireEvent.change(selector, { target: { value: 'sisyphus' } });
    expect(mockProps.onModeChange).toHaveBeenCalledWith('sisyphus');
  });

  it('renders config button', () => {
    render(<AgentControls {...mockProps} />);
    expect(screen.getByText('⚙️')).toBeInTheDocument();
  });

  it('calls onOpenConfig when config button clicked', () => {
    render(<AgentControls {...mockProps} />);
    const button = screen.getByText('⚙️');
    fireEvent.click(button);
    expect(mockProps.onOpenConfig).toHaveBeenCalled();
  });

  it('renders with sisyphus mode', () => {
    render(<AgentControls {...mockProps} mode="sisyphus" />);
    const selector = screen.getByDisplayValue(/Sisyphus/);
    expect(selector).toBeInTheDocument();
  });

  it('renders with researcher mode', () => {
    render(<AgentControls {...mockProps} mode="researcher" />);
    const selector = screen.getByDisplayValue(/Researcher/);
    expect(selector).toBeInTheDocument();
  });
});

