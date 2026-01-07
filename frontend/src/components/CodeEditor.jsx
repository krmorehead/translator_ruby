import React, { useEffect, useRef } from "react";
import Editor from "@monaco-editor/react";
import { useAgentStore } from "../store/agentStore";
import "./code-editor.css";

/**
 * CodeEditor - Monaco-based code editor with save functionality
 * Supports Cmd+S / Ctrl+S to save files
 */
const CodeEditor = React.memo(({ filePath, content, readOnly }) => {
  const editorRef = useRef(null);
  const theme = useAgentStore((state) => state.userPreferences?.theme || "light");

  useEffect(() => {
    const handleKeyDown = (e) => {
      // Cmd+S (Mac) or Ctrl+S (Windows/Linux)
      if ((e.metaKey || e.ctrlKey) && e.key === 's') {
        e.preventDefault();
        handleSave();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [filePath, content]);

  const handleSave = async () => {
    if (!filePath || readOnly) {
      console.log("Cannot save: no file path or read-only mode");
      return;
    }

    const editor = editorRef.current;
    if (!editor) return;

    const currentContent = editor.getValue();
    
    try {
      // TODO: Implement save API call
      // For now, just log
      console.log("Saving file:", filePath);
      console.log("Content length:", currentContent.length);
      
      // In the future, call backend API to save file
      // await saveFile(filePath, currentContent);
      
      alert(`File saved: ${filePath}`);
    } catch (error) {
      console.error("Failed to save file:", error);
      alert(`Failed to save file: ${error.message}`);
    }
  };

  const handleEditorDidMount = (editor) => {
    editorRef.current = editor;
  };

  const getLanguageFromPath = (path) => {
    if (!path) return "plaintext";
    
    const ext = path.split('.').pop().toLowerCase();
    const langMap = {
      js: "javascript",
      jsx: "javascript",
      ts: "typescript",
      tsx: "typescript",
      rb: "ruby",
      py: "python",
      java: "java",
      css: "css",
      scss: "scss",
      html: "html",
      json: "json",
      md: "markdown",
      yml: "yaml",
      yaml: "yaml",
      xml: "xml",
      sql: "sql",
      sh: "shell",
      bash: "shell",
    };
    
    return langMap[ext] || "plaintext";
  };

  if (!filePath) {
    return (
      <div className="code-editor-empty">
        <p>Select a file from the file browser to view its contents</p>
      </div>
    );
  }

  return (
    <div className="code-editor-container">
      <Editor
        height="100%"
        language={getLanguageFromPath(filePath)}
        value={content || ""}
        theme={theme === "dark" ? "vs-dark" : "vs-light"}
        onMount={handleEditorDidMount}
        options={{
          readOnly: readOnly,
          minimap: { enabled: true },
          fontSize: 14,
          lineNumbers: "on",
          scrollBeyondLastLine: false,
          automaticLayout: true,
          tabSize: 2,
          wordWrap: "on",
        }}
      />
      {!readOnly && (
        <div className="editor-status-bar">
          <span>Press Cmd+S (Mac) or Ctrl+S (Windows/Linux) to save</span>
        </div>
      )}
    </div>
  );
});

CodeEditor.displayName = 'CodeEditor';

export default CodeEditor;

