import React, { useState } from "react";
import { useAgentStore } from "../store/agentStore";
import "./file-tree.css";

/**
 * FileTreeBrowser - Displays project file tree with expand/collapse
 * Uses existing loadFileTree API from agentStore
 */
const FileTreeBrowser = React.memo(({ onFileSelect }) => {
  const [expandedDirs, setExpandedDirs] = useState(new Set());
  
  const fileTree = useAgentStore((state) => state.sisyphus.fileTree);
  const fileLoading = useAgentStore((state) => state.sisyphus.fileLoading);
  const fileError = useAgentStore((state) => state.sisyphus.fileError);
  const selectedFile = useAgentStore((state) => state.sisyphus.selectedFile);

  const toggleDir = (path) => {
    const newExpanded = new Set(expandedDirs);
    if (newExpanded.has(path)) {
      newExpanded.delete(path);
    } else {
      newExpanded.add(path);
    }
    setExpandedDirs(newExpanded);
  };

  const handleFileClick = (filePath) => {
    if (onFileSelect) {
      onFileSelect(filePath);
    }
  };

  const getFileIcon = (name) => {
    const ext = name.split('.').pop().toLowerCase();
    const iconMap = {
      js: '📜',
      jsx: '⚛️',
      ts: '📘',
      tsx: '⚛️',
      rb: '💎',
      py: '🐍',
      java: '☕',
      css: '🎨',
      html: '🌐',
      json: '📋',
      md: '📝',
      yml: '⚙️',
      yaml: '⚙️',
      txt: '📄',
      png: '🖼️',
      jpg: '🖼️',
      svg: '🎨',
    };
    return iconMap[ext] || '📄';
  };

  const renderTreeNode = (node, path = "") => {
    if (!node) return null;

    const fullPath = path ? `${path}/${node.name}` : node.name;
    const isExpanded = expandedDirs.has(fullPath);
    const isSelected = selectedFile === fullPath;

    if (node.type === "directory") {
      return (
        <div key={fullPath} className="tree-node">
          <div
            className="tree-item directory"
            onClick={() => toggleDir(fullPath)}
          >
            <span className="expand-icon">{isExpanded ? '▼' : '▶'}</span>
            <span className="icon">📁</span>
            <span className="name">{node.name}</span>
          </div>
          {isExpanded && node.children && (
            <div className="tree-children">
              {node.children.map((child) => renderTreeNode(child, fullPath))}
            </div>
          )}
        </div>
      );
    }

    // File node
    return (
      <div key={fullPath} className="tree-node">
        <div
          className={`tree-item file ${isSelected ? 'selected' : ''}`}
          onClick={() => handleFileClick(fullPath)}
        >
          <span className="icon">{getFileIcon(node.name)}</span>
          <span className="name">{node.name}</span>
        </div>
      </div>
    );
  };

  if (fileLoading) {
    return (
      <div className="file-tree-loading">
        <p>Loading file tree...</p>
      </div>
    );
  }

  if (fileError) {
    return (
      <div className="file-tree-error">
        <p>Error: {fileError}</p>
      </div>
    );
  }

  if (!fileTree) {
    return (
      <div className="file-tree-empty">
        <p>Enter a project path and click "Load Project" to browse files</p>
      </div>
    );
  }

  return (
    <div className="file-tree-browser">
      {fileTree.children ? (
        fileTree.children.map((node) => renderTreeNode(node, ""))
      ) : (
        <div className="file-tree-empty">
          <p>No files found</p>
        </div>
      )}
    </div>
  );
});

FileTreeBrowser.displayName = 'FileTreeBrowser';

export default FileTreeBrowser;

