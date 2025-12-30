import { useState } from "react";
import "./project-plan.css";

function PlanViewer({
  milestones,
  fileReferencesPath,
  projectPlanPath,
  projectPath,
  researchSummary,
  existingFiles,
  plannedFiles
}) {
  const [expandedMilestones, setExpandedMilestones] = useState(
    milestones.map((_, i) => i === 0) // First milestone expanded by default
  );

  const toggleMilestone = (index) => {
    setExpandedMilestones((prev) =>
      prev.map((expanded, i) => (i === index ? !expanded : expanded))
    );
  };

  const copyToClipboard = (text) => {
    navigator.clipboard.writeText(text);
  };

  return (
    <div className="plan-viewer">
      <div className="plan-success-banner">
        <span className="success-icon">✓</span>
        <span>Project plan generated successfully!</span>
      </div>

      <div className="plan-paths">
        <h3>Generated Files</h3>
        <div className="path-item">
          <code>{projectPath}</code>
          <button 
            className="copy-btn" 
            onClick={() => copyToClipboard(projectPath)}
            title="Copy path"
          >
            📋
          </button>
        </div>
        <div className="path-links">
          <div className="path-link">
            <span className="file-icon">📄</span>
            <span>file_references.md</span>
            <button 
              className="copy-btn" 
              onClick={() => copyToClipboard(fileReferencesPath)}
              title="Copy path"
            >
              📋
            </button>
          </div>
          <div className="path-link">
            <span className="file-icon">📋</span>
            <span>project_plan.md</span>
            <button 
              className="copy-btn" 
              onClick={() => copyToClipboard(projectPlanPath)}
              title="Copy path"
            >
              📋
            </button>
          </div>
        </div>
      </div>

      {researchSummary && (
        <div className="research-summary">
          <h3>Research Summary</h3>
          <p>{researchSummary}</p>
        </div>
      )}

      <div className="files-summary">
        <div className="files-column">
          <h4>Existing Files ({existingFiles.length})</h4>
          <ul className="file-list">
            {existingFiles.slice(0, 5).map((file, i) => (
              <li key={i}>
                <code>{file.path}</code>
              </li>
            ))}
            {existingFiles.length > 5 && (
              <li className="more-files">+{existingFiles.length - 5} more</li>
            )}
          </ul>
        </div>
        <div className="files-column">
          <h4>Planned Files ({plannedFiles.length})</h4>
          <ul className="file-list">
            {plannedFiles.slice(0, 5).map((file, i) => (
              <li key={i}>
                <code>{file.path}</code>
                <span className="step-ref">Step {file.created_in}</span>
              </li>
            ))}
            {plannedFiles.length > 5 && (
              <li className="more-files">+{plannedFiles.length - 5} more</li>
            )}
          </ul>
        </div>
      </div>

      <div className="milestones">
        <h3>Milestones ({milestones.length})</h3>
        {milestones.map((milestone, mIndex) => (
          <div key={mIndex} className="milestone">
            <button
              className="milestone-header"
              onClick={() => toggleMilestone(mIndex)}
            >
              <span className="milestone-toggle">
                {expandedMilestones[mIndex] ? "▼" : "▶"}
              </span>
              <span className="milestone-number">{milestone.number}</span>
              <span className="milestone-title">{milestone.title}</span>
              <span className="step-count">
                {(milestone.steps || []).length} steps
              </span>
            </button>
            
            {expandedMilestones[mIndex] && (
              <div className="milestone-content">
                <p className="milestone-description">{milestone.description}</p>
                <div className="steps">
                  {(milestone.steps || []).map((step, sIndex) => (
                    <div key={sIndex} className="step">
                      <div className="step-header">
                        <span className="step-number">{step.number}</span>
                        <span className="step-title">{step.title}</span>
                      </div>
                      
                      <div className="step-section">
                        <h5>Intent</h5>
                        <p>{step.intent}</p>
                      </div>
                      
                      <div className="step-section">
                        <h5>Details</h5>
                        <ul>
                          {(step.details || []).map((detail, dIndex) => (
                            <li key={dIndex}>{detail}</li>
                          ))}
                        </ul>
                      </div>
                      
                      <div className="step-section step-tests">
                        <h5>Tests</h5>
                        <ul>
                          {(step.tests || []).map((test, tIndex) => (
                            <li key={tIndex}>{test}</li>
                          ))}
                        </ul>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

export default PlanViewer;

