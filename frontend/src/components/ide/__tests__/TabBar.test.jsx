import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { TabBar } from '../TabBar';

describe('TabBar', () => {
  const mockProps = {
    activeTab: 'chat',
    onTabChange: vi.fn(),
  };

  it('renders all tabs', () => {
    render(<TabBar {...mockProps} />);
    expect(screen.getByText('💬 Chat')).toBeInTheDocument();
    expect(screen.getByText('💭 Thoughts')).toBeInTheDocument();
    expect(screen.getByText('📁 Context')).toBeInTheDocument();
    expect(screen.getByText('⏱️ Timeline')).toBeInTheDocument();
    expect(screen.getByText('📍 Checkpoints')).toBeInTheDocument();
  });

  it('marks active tab with active class', () => {
    render(<TabBar {...mockProps} activeTab="chat" />);
    const chatTab = screen.getByText('💬 Chat').closest('button');
    expect(chatTab).toHaveClass('active');
  });

  it('does not mark inactive tabs with active class', () => {
    render(<TabBar {...mockProps} activeTab="chat" />);
    const thoughtsTab = screen.getByText('💭 Thoughts').closest('button');
    expect(thoughtsTab).not.toHaveClass('active');
  });

  it('calls onTabChange when tab clicked', () => {
    render(<TabBar {...mockProps} />);
    const thoughtsTab = screen.getByText('💭 Thoughts');
    fireEvent.click(thoughtsTab);
    expect(mockProps.onTabChange).toHaveBeenCalledWith('thoughts');
  });

  it('calls onTabChange with correct tab id for each tab', () => {
    const onTabChange = vi.fn();
    render(<TabBar {...mockProps} onTabChange={onTabChange} />);
    
    fireEvent.click(screen.getByText('💬 Chat'));
    expect(onTabChange).toHaveBeenCalledWith('chat');
    
    fireEvent.click(screen.getByText('💭 Thoughts'));
    expect(onTabChange).toHaveBeenCalledWith('thoughts');
    
    fireEvent.click(screen.getByText('📁 Context'));
    expect(onTabChange).toHaveBeenCalledWith('context');
    
    fireEvent.click(screen.getByText('⏱️ Timeline'));
    expect(onTabChange).toHaveBeenCalledWith('timeline');
    
    fireEvent.click(screen.getByText('📍 Checkpoints'));
    expect(onTabChange).toHaveBeenCalledWith('checkpoints');
  });

  it('updates active class when activeTab prop changes', () => {
    const { rerender } = render(<TabBar {...mockProps} activeTab="chat" />);
    let chatTab = screen.getByText('💬 Chat').closest('button');
    expect(chatTab).toHaveClass('active');
    
    rerender(<TabBar {...mockProps} activeTab="thoughts" />);
    chatTab = screen.getByText('💬 Chat').closest('button');
    const thoughtsTab = screen.getByText('💭 Thoughts').closest('button');
    expect(chatTab).not.toHaveClass('active');
    expect(thoughtsTab).toHaveClass('active');
  });
});

