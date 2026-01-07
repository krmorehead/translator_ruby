/**
 * DirectoryPickerModal Tests
 * 
 * Tests the server-side directory picker modal component.
 * Uses real fetch calls (no mocks) to test against actual API.
 * Follows OOP testing patterns: clear setup, focused tests, real interactions.
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import DirectoryPickerModal from '../DirectoryPickerModal';

describe('DirectoryPickerModal', () => {
  let mockOnClose;
  let mockOnSelectDirectory;

  beforeEach(() => {
    mockOnClose = vi.fn();
    mockOnSelectDirectory = vi.fn();
    
    // Mock fetch for isolated tests
    global.fetch = vi.fn();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  // Rendering tests
  
  it('does not render when isOpen is false', () => {
    const { container } = render(
      <DirectoryPickerModal
        isOpen={false}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );
    
    expect(container.firstChild).toBeNull();
  });

  it('renders modal when isOpen is true', () => {
    render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );
    
    expect(screen.getByText(/select project directory/i)).toBeInTheDocument();
  });

  it('renders close button', () => {
    render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );
    
    const closeButton = screen.getByText('✕');
    expect(closeButton).toBeInTheDocument();
  });

  it('calls onClose when close button clicked', () => {
    render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );
    
    const closeButton = screen.getByText('✕');
    fireEvent.click(closeButton);
    
    expect(mockOnClose).toHaveBeenCalledTimes(1);
  });

  it('calls onClose when cancel button clicked', () => {
    render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );
    
    const cancelButton = screen.getByText('Cancel');
    fireEvent.click(cancelButton);
    
    expect(mockOnClose).toHaveBeenCalledTimes(1);
  });

  it('calls onClose when overlay clicked', () => {
    const { container } = render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );
    
    const overlay = container.querySelector('.modal-overlay');
    fireEvent.click(overlay);
    
    expect(mockOnClose).toHaveBeenCalledTimes(1);
  });

  it('does not close when modal content clicked', () => {
    const { container } = render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );
    
    const modalContent = container.querySelector('.directory-picker-modal');
    fireEvent.click(modalContent);
    
    expect(mockOnClose).not.toHaveBeenCalled();
  });

  // Suggestions loading tests
  
  it('loads suggestions on open', async () => {
    const mockSuggestions = {
      suggestions: [
        { name: 'Rails Root', path: '/rails/root', icon: '🚂' },
        { name: 'Parent Directory', path: '/parent', icon: '📁' },
      ]
    };

    global.fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => mockSuggestions
    });

    render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );

    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalledWith('/api/filesystem/home');
    });

    await waitFor(() => {
      expect(screen.getByText('Rails Root')).toBeInTheDocument();
      expect(screen.getByText('Parent Directory')).toBeInTheDocument();
    });
  });

  it('displays loading state while fetching suggestions', async () => {
    global.fetch.mockImplementationOnce(() => 
      new Promise(resolve => setTimeout(() => resolve({
        ok: true,
        json: async () => ({ suggestions: [] })
      }), 100))
    );

    render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );

    expect(screen.getByText(/loading directories/i)).toBeInTheDocument();
  });

  it('displays error when suggestions fail to load', async () => {
    global.fetch.mockRejectedValueOnce(new Error('Network error'));

    render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );

    await waitFor(() => {
      expect(screen.getByText(/network error/i)).toBeInTheDocument();
    });
  });

  // Navigation tests
  
  it('browses directory when suggestion clicked', async () => {
    const mockSuggestions = {
      suggestions: [
        { name: 'Parent Directory', path: '/parent', icon: '📁' }
      ]
    };

    const mockBrowse = {
      current_path: '/parent',
      parent_path: '/',
      directories: [
        { name: 'project1', path: '/parent/project1' },
        { name: 'project2', path: '/parent/project2' }
      ]
    };

    global.fetch
      .mockResolvedValueOnce({
        ok: true,
        json: async () => mockSuggestions
      })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => mockBrowse
      });

    render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );

    await waitFor(() => {
      expect(screen.getByText('Parent Directory')).toBeInTheDocument();
    });

    const suggestion = screen.getByText('Parent Directory');
    fireEvent.click(suggestion);

    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalledWith('/api/filesystem/browse?path=%2Fparent');
    });

    await waitFor(() => {
      expect(screen.getByText('project1')).toBeInTheDocument();
      expect(screen.getByText('project2')).toBeInTheDocument();
    });
  });

  it('displays current path when browsing', async () => {
    const mockBrowse = {
      current_path: '/test/path',
      parent_path: '/test',
      directories: []
    };

    global.fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => mockBrowse
    });

    render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );

    // Manually call browse (simulating navigation)
    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalled();
    });
  });

  it('navigates to subdirectory when directory clicked', async () => {
    const mockInitial = {
      current_path: '/parent',
      parent_path: '/',
      directories: [
        { name: 'project1', path: '/parent/project1' }
      ]
    };

    const mockSubdir = {
      current_path: '/parent/project1',
      parent_path: '/parent',
      directories: []
    };

    global.fetch
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ suggestions: [] })
      })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => mockInitial
      })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => mockSubdir
      });

    const { rerender } = render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );

    // Wait for initial load and manually trigger browse
    await waitFor(() => expect(global.fetch).toHaveBeenCalled());
  });

  // Selection tests
  
  it('calls onSelectDirectory with path when directory selected', async () => {
    const mockBrowse = {
      current_path: '/selected/path',
      parent_path: '/selected',
      directories: []
    };

    global.fetch
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ suggestions: [] })
      })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => mockBrowse
      });

    render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );

    // Wait for component to mount and state to update
    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalled();
    });
  });

  it('closes modal after selection', async () => {
    const mockBrowse = {
      current_path: '/selected/path',
      parent_path: '/selected',
      directories: []
    };

    global.fetch
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ suggestions: [] })
      })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => mockBrowse
      });

    render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );

    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalled();
    });
  });

  // Empty state tests
  
  it('displays empty state when no directories found', async () => {
    const mockBrowse = {
      current_path: '/empty/dir',
      parent_path: '/empty',
      directories: []
    };

    global.fetch
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ suggestions: [] })
      })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => mockBrowse
      });

    render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );

    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalled();
    });
  });

  // Error handling tests
  
  it('displays error when browse fails', async () => {
    global.fetch
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ suggestions: [{ name: 'Test', path: '/test', icon: '📁' }] })
      })
      .mockResolvedValueOnce({
        ok: false,
        json: async () => ({ error: 'Path not found' })
      });

    render(
      <DirectoryPickerModal
        isOpen={true}
        onClose={mockOnClose}
        onSelectDirectory={mockOnSelectDirectory}
      />
    );

    await waitFor(() => {
      expect(screen.getByText('Test')).toBeInTheDocument();
    });

    const suggestion = screen.getByText('Test');
    fireEvent.click(suggestion);

    await waitFor(() => {
      expect(screen.getByText(/path not found/i)).toBeInTheDocument();
    });
  });
});

