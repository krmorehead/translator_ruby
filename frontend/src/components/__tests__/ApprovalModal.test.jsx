import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import ApprovalModal from '../ApprovalModal';

describe('ApprovalModal', () => {
  const mockApproval = {
    id: 'approval-123',
    type: 'step',
    subject_title: 'Install dependencies',
    created_at: new Date().toISOString(),
    timeout_at: new Date(Date.now() + 60000).toISOString(),
    execution_id: 'exec-123',
    planned_actions: ['Run npm install'],
  };

  const mockHandlers = {
    onApprove: vi.fn(),
    onReject: vi.fn(),
    onClose: vi.fn()
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders null when approval is null', () => {
    const { container } = render(
      <ApprovalModal 
        approval={null}
        {...mockHandlers}
      />
    );
    expect(container.firstChild).toBeNull();
  });

  it('renders approval modal with step details', () => {
    render(
      <ApprovalModal 
        approval={mockApproval}
        {...mockHandlers}
      />
    );
    
    expect(screen.getByText(/Approval Required/i)).toBeInTheDocument();
    expect(screen.getByText(mockApproval.subject_title)).toBeInTheDocument();
    expect(screen.getByText(mockApproval.planned_actions[0])).toBeInTheDocument();
  });

  it('calls onApprove when approve button clicked', () => {
    render(
      <ApprovalModal 
        approval={mockApproval}
        {...mockHandlers}
      />
    );
    
    const approveBtn = screen.getByRole('button', { name: /approve/i });
    fireEvent.click(approveBtn);
    
    expect(mockHandlers.onApprove).toHaveBeenCalledWith(mockApproval.id);
  });

  it('calls onReject when reject button clicked', () => {
    render(
      <ApprovalModal 
        approval={mockApproval}
        {...mockHandlers}
      />
    );
    
    const rejectBtn = screen.getByRole('button', { name: /reject/i });
    fireEvent.click(rejectBtn);
    
    expect(mockHandlers.onReject).toHaveBeenCalledWith(mockApproval.id);
  });

  it('calls onClose when backdrop clicked', () => {
    render(
      <ApprovalModal 
        approval={mockApproval}
        {...mockHandlers}
      />
    );
    
    const backdrop = document.querySelector('.approval-modal-backdrop');
    fireEvent.click(backdrop);
    
    expect(mockHandlers.onClose).toHaveBeenCalled();
  });

  it('disables buttons when loading', () => {
    render(
      <ApprovalModal 
        approval={mockApproval}
        loading={true}
        {...mockHandlers}
      />
    );
    
    const buttons = screen.getAllByRole('button', { name: /processing/i });
    // There should be 2 buttons with "Processing..." text (Reject and Approve)
    expect(buttons).toHaveLength(2);
    buttons.forEach(button => {
      expect(button).toBeDisabled();
    });
  });

  it('renders milestone approval differently', () => {
    const milestoneApproval = {
      ...mockApproval,
      type: 'milestone',
      subject_title: 'Phase 1 Complete'
    };
    
    render(
      <ApprovalModal 
        approval={milestoneApproval}
        {...mockHandlers}
      />
    );
    
    expect(screen.getByText(/Approval Required/i)).toBeInTheDocument();
    expect(screen.getByText(milestoneApproval.subject_title)).toBeInTheDocument();
    expect(screen.getByText(/Milestone:/i)).toBeInTheDocument();
  });

  it('does not call handlers when loading', () => {
    render(
      <ApprovalModal 
        approval={mockApproval}
        loading={true}
        {...mockHandlers}
      />
    );
    
    const buttons = screen.getAllByRole('button', { name: /processing/i });
    const approveBtn = buttons.find(btn => btn.className.includes('approve'));
    fireEvent.click(approveBtn);
    
    expect(mockHandlers.onApprove).not.toHaveBeenCalled();
  });
});

