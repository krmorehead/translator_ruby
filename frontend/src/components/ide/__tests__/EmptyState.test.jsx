import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { EmptyState } from '../EmptyState';

describe('EmptyState', () => {
  it('renders default message', () => {
    render(<EmptyState />);
    expect(screen.getByText(/Initialize a session to start chatting/)).toBeInTheDocument();
  });

  it('renders custom message', () => {
    render(<EmptyState message="Custom empty state message" />);
    expect(screen.getByText('Custom empty state message')).toBeInTheDocument();
  });

  it('has correct structure', () => {
    const { container } = render(<EmptyState />);
    expect(container.querySelector('.empty-state')).toBeInTheDocument();
  });
});

