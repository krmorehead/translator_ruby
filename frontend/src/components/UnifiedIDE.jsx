/**
 * UnifiedIDE - Main IDE Orchestrator (Refactored)
 * 
 * Orchestrates the IDE by composing smaller, focused components.
 * Manages only local UI state (modals, active tab).
 * Delegates all business logic to hooks and child components.
 * 
 * OOP Principles Applied:
 * - Single Responsibility: Orchestration only
 * - Dependency Inversion: Depends on hooks, not stores
 * - Composition: Built from smaller components
 * - Open/Closed: Extensible via composition
 * 
 * Lines: ~140 (down from 316)
 */

import React, { useState } from "react";
import { useIDEState } from "../hooks/ide/useIDEState";
import { useIDEActions } from "../hooks/ide/useIDEActions";
import { useIDEKeyboardShortcuts } from "../hooks/ide/useIDEKeyboardShortcuts";
import IDEHeader from "./ide/IDEHeader";
import IDELayout from "./ide/IDELayout";
import Panel from "./ide/Panel";
import AgentControls from "./ide/AgentControls";
import TabBar from "./ide/TabBar";
import TabContent from "./ide/TabContent";
import ModalManager from "./ide/ModalManager";
import EmptyState from "./ide/EmptyState";
import FileTreeBrowser from "./FileTreeBrowser";
import CodeEditor from "./CodeEditor";
import MemoryInspector from "./MemoryInspector";
import PersistentContext from "./PersistentContext";
import ErrorBoundary from "./ErrorBoundary";
import DirectoryPickerModal from "./DirectoryPickerModal";
import "./unified-ide.css";

function UnifiedIDE() {
  // Local UI state (presentation layer only)
  const [activeTab, setActiveTab] = useState("chat");
  const [modals, setModals] = useState({
    config: false,
    preferences: false,
  });

  // Business logic hooks (separates concerns)
  const state = useIDEState();
  const actions = useIDEActions();
  
  // Keyboard shortcuts (behavior layer)
  useIDEKeyboardShortcuts(actions, state, {
    activeTab,
    setActiveTab,
    toggleConfig: () => setModals(m => ({ ...m, config: !m.config })),
  });

  // Modal handlers (presentation logic)
  const closeConfig = () => setModals(m => ({ ...m, config: false }));
  const closePreferences = () => setModals(m => ({ ...m, preferences: false }));
  const openConfig = () => setModals(m => ({ ...m, config: true }));
  const openPreferences = () => setModals(m => ({ ...m, preferences: true }));
  
  // Directory picker modal state
  const [showDirectoryPicker, setShowDirectoryPicker] = useState(false);

  // Handle directory selection from modal
  const handleSelectDirectory = (path) => {
    actions.project.setPath(path);
    setShowDirectoryPicker(false);
  };
  
  // Enhanced load project that auto-initializes session
  const handleLoadProject = () => {
    actions.project.loadFileTree();
    
    // Auto-initialize session when project path is loaded
    if (state.project.path && !state.session.isActive) {
      actions.session.initialize();
    }
  };

  return (
    <div className="unified-ide">
      {/* Modal Layer */}
      <ModalManager
        approval={{
          visible: state.approval.isVisible,
          data: state.approval.pending,
          loading: state.approval.loading,
          onApprove: actions.approval.approve,
          onReject: actions.approval.reject,
          onClose: actions.approval.close,
        }}
        config={{
          visible: modals.config,
          onClose: closeConfig,
        }}
        preferences={{
          visible: modals.preferences,
          onClose: closePreferences,
        }}
      />

      {/* Header */}
      <IDEHeader
        sessionId={state.session.id}
        projectPath={state.project.path}
        onProjectPathChange={actions.project.setPath}
        onLoadProject={handleLoadProject}
        onBrowseDirectory={() => setShowDirectoryPicker(true)}
        onInitializeSession={actions.session.initialize}
        onOpenPreferences={openPreferences}
        showInitButton={!state.session.isActive}
      />

      {/* Directory Picker Modal */}
      <DirectoryPickerModal
        isOpen={showDirectoryPicker}
        onClose={() => setShowDirectoryPicker(false)}
        onSelectDirectory={handleSelectDirectory}
      />

      {/* Persistent Context Bar */}
      {state.session.isActive && (
        <div className="persistent-context-bar">
          <PersistentContext compact={true} />
        </div>
      )}

      {/* Three-Panel Layout */}
      <IDELayout
        leftPanel={
          <Panel title="Files" icon="📁" showHeader={true}>
            <ErrorBoundary>
              <FileTreeBrowser onFileSelect={actions.file.select} />
            </ErrorBoundary>
          </Panel>
        }
        middlePanel={
          <>
            <div className="editor-section">
              <div className="panel-header">
                <h3>📝 Editor</h3>
                {state.file.selected && (
                  <span className="file-name">{state.file.selected}</span>
                )}
              </div>
              <div className="editor-container">
                <ErrorBoundary>
                  <CodeEditor
                    filePath={state.file.selected}
                    content={state.file.content}
                    readOnly={!state.project.isLoaded}
                  />
                </ErrorBoundary>
              </div>
            </div>
            <div className="memory-section">
              <div className="panel-header">
                <h3>🧠 Memory</h3>
              </div>
              <div className="memory-container">
                <ErrorBoundary>
                  <MemoryInspector />
                </ErrorBoundary>
              </div>
            </div>
          </>
        }
        rightPanel={
          <>
            <div className="panel-header">
              <h3>🤖 Agent</h3>
              <AgentControls
                mode={state.agent.mode}
                onModeChange={actions.agent.changeMode}
                onOpenConfig={openConfig}
              />
            </div>

            {state.session.isActive ? (
              <>
                <TabBar
                  activeTab={activeTab}
                  onTabChange={setActiveTab}
                />
                <div className="panel-content">
                  <TabContent activeTab={activeTab} />
                </div>
              </>
            ) : (
              <div className="panel-content">
                <EmptyState />
              </div>
            )}
          </>
        }
      />
    </div>
  );
}

export default UnifiedIDE;
