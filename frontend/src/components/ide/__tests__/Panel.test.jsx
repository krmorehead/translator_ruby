import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Panel } from '../Panel';

describe('Panel', () => {
  it('renders children', () => {
    render(
      <Panel title="Test Panel">
        <div>Test Content</div>
      </Panel>
    );
    expect(screen.getByText('Test Content')).toBeInTheDocument();
  });

  it('renders title in header', () => {
    render(
      <Panel title="Test Panel">
        <div>Content</div>
      </Panel>
    );
    expect(screen.getByText('Test Panel')).toBeInTheDocument();
  });

  it('renders icon with title', () => {
    render(
      <Panel title="Test Panel" icon="🎨">
        <div>Content</div>
      </Panel>
    );
    expect(screen.getByText(/🎨 Test Panel/)).toBeInTheDocument();
  });

  it('applies custom className', () => {
    const { container } = render(
      <Panel title="Test" className="custom-class">
        <div>Content</div>
      </Panel>
    );
    expect(container.querySelector('.custom-class')).toBeInTheDocument();
  });

  it('shows header by default', () => {
    render(
      <Panel title="Test Panel">
        <div>Content</div>
      </Panel>
    );
    expect(screen.getByText('Test Panel')).toBeInTheDocument();
  });

  it('hides header when showHeader is false', () => {
    render(
      <Panel title="Test Panel" showHeader={false}>
        <div>Content</div>
      </Panel>
    );
    expect(screen.queryByText('Test Panel')).not.toBeInTheDocument();
  });

  it('renders multiple children', () => {
    render(
      <Panel title="Test">
        <div>Child 1</div>
        <div>Child 2</div>
        <div>Child 3</div>
      </Panel>
    );
    expect(screen.getByText('Child 1')).toBeInTheDocument();
    expect(screen.getByText('Child 2')).toBeInTheDocument();
    expect(screen.getByText('Child 3')).toBeInTheDocument();
  });

  it('has correct structure', () => {
    const { container } = render(
      <Panel title="Test">
        <div>Content</div>
      </Panel>
    );
    expect(container.querySelector('.panel')).toBeInTheDocument();
    expect(container.querySelector('.panel-header')).toBeInTheDocument();
    expect(container.querySelector('.panel-content')).toBeInTheDocument();
  });
});

