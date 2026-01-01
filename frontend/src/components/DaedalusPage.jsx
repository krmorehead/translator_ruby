import { useDaedalusStore } from "../store/daedalusStore";
import LoadingIndicator from "./LoadingIndicator";
import "./project-plan.css";

function DaedalusPage() {
  const goal = useDaedalusStore((state) => state.goal);
  const path = useDaedalusStore((state) => state.path);
  const contextHint = useDaedalusStore((state) => state.contextHint);
  const loading = useDaedalusStore((state) => state.loading);
  const error = useDaedalusStore((state) => state.error);
  const result = useDaedalusStore((state) => state.result);
  const setGoal = useDaedalusStore((state) => state.setGoal);
  const setPath = useDaedalusStore((state) => state.setPath);
  const setContextHint = useDaedalusStore((state) => state.setContextHint);
  const createPlan = useDaedalusStore((state) => state.createPlan);
  const reset = useDaedalusStore((state) => state.reset);

  const handleSubmit = (e) => {
    e.preventDefault();
    createPlan();
  };

  const renderMilestone = (milestone, index) => {
    return (
      <div key={milestone.id} className="milestone-card">
        <div className="milestone-header">
          <h3>Milestone {index + 1}: {milestone.title}</h3>
        </div>
        <p className="milestone-description">{milestone.description}</p>
        
        <p className="milestone-duration">
          <strong>Estimated Duration:</strong> {milestone.estimated_duration}
        </p>
        
        <div className="success-criteria">
          <strong>Success Criteria:</strong>
          <ul>
            {milestone.success_criteria.map((criteria, i) => (
              <li key={i}>{criteria}</li>
            ))}
          </ul>
        </div>

        <div className="steps-section">
          <h4>Steps ({milestone.steps.length})</h4>
          {milestone.steps.map((step, stepIndex) => (
            <div key={step.id} className="step-card">
              <div className="step-header">
                <h5>Step {step.milestone_number}.{step.step_number}: {step.title}</h5>
              </div>
              
              <p className="step-intent"><strong>Intent:</strong> {step.intent}</p>
              
              <div className="step-details">
                <strong>Details:</strong>
                <ul>
                  {step.details.map((detail, i) => (
                    <li key={i}>{detail}</li>
                  ))}
                </ul>
              </div>
              
              <div className="step-tests">
                <strong>Tests:</strong>
                <ul>
                  {step.tests.map((test, i) => (
                    <li key={i}>{test}</li>
                  ))}
                </ul>
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  };

  return (
    <div className="project-plan-page">
      <header className="plan-header">
        <div className="header-content">
          <p className="eyebrow">Daedalus 🏛️</p>
          <h1>Master Architect & Planner</h1>
          <p className="subtitle">Generate detailed execution plans from codebase analysis</p>
        </div>
        {loading && <LoadingIndicator />}
      </header>

      <main className="plan-main">
        <section className="plan-form-section">
          <form onSubmit={handleSubmit} className="plan-form">
            <div className="form-group">
              <label htmlFor="goal">Goal</label>
              <textarea
                id="goal"
                value={goal}
                onChange={(e) => setGoal(e.target.value)}
                placeholder="Describe what you want to accomplish (e.g., 'Add user authentication system')..."
                rows={4}
                disabled={loading}
              />
            </div>

            <div className="form-group">
              <label htmlFor="path">Codebase Path</label>
              <input
                type="text"
                id="path"
                value={path}
                onChange={(e) => setPath(e.target.value)}
                placeholder="/path/to/your/codebase"
                disabled={loading}
              />
            </div>

            <div className="form-group">
              <label htmlFor="contextHint">Context Hint (Optional)</label>
              <input
                type="text"
                id="contextHint"
                value={contextHint}
                onChange={(e) => setContextHint(e.target.value)}
                placeholder="E.g., 'Look at existing authentication patterns'"
                disabled={loading}
              />
              <small>Optional hint to guide the analysis</small>
            </div>

            <div className="form-actions">
              <button 
                type="submit" 
                className="btn-primary"
                disabled={loading || !goal || !path}
              >
                {loading ? "Generating Plan..." : "Generate Execution Plan"}
              </button>
              <button 
                type="button" 
                className="btn-secondary"
                onClick={reset}
                disabled={loading}
              >
                Reset
              </button>
            </div>
          </form>

          {error && (
            <div className="banner banner-error">
              <strong>Error:</strong> {error}
            </div>
          )}
        </section>

        {result && (
          <section className="plan-result-section">
            <div className="result-header">
              <h2>📋 Execution Plan</h2>
              <div className="result-meta">
                <span>{result.metadata.milestone_count} Milestones</span>
                <span>{result.metadata.step_count} Steps</span>
              </div>
            </div>

            <div className="plan-goal">
              <h3>Goal</h3>
              <p>{result.result.execution_plan.goal}</p>
            </div>

            <div className="plan-section">
              <h3>⚠️ Constraints</h3>
              <ul>
                {result.result.execution_plan.constraints.map((constraint, i) => (
                  <li key={i}>{constraint}</li>
                ))}
              </ul>
            </div>

            <div className="plan-section">
              <h3>💡 Assumptions</h3>
              <ul>
                {result.result.execution_plan.assumptions.map((assumption, i) => (
                  <li key={i}>{assumption}</li>
                ))}
              </ul>
            </div>

            <div className="plan-section">
              <h3>⚠️ Risks</h3>
              <ul>
                {result.result.execution_plan.risks.map((risk, i) => (
                  <li key={i}>{risk}</li>
                ))}
              </ul>
            </div>

            <div className="milestones-section">
              <h3>🎯 Milestones</h3>
              {result.result.execution_plan.milestones.map((milestone, index) => 
                renderMilestone(milestone, index)
              )}
            </div>

            <div className="output-paths">
              <h3>📁 Output Files</h3>
              <p><strong>Plan Markdown:</strong> <code>{result.result.output_paths.plan_path}</code></p>
              <p><strong>Plan JSON:</strong> <code>{result.result.output_paths.json_path}</code></p>
              <p><strong>Metadata:</strong> <code>{result.result.output_paths.metadata_path}</code></p>
            </div>

            <div className="analysis-summary">
              <h3>🔍 Analysis Summary</h3>
              <div>
                <strong>Relevant Files ({result.result.analysis_summary.relevant_files.length}):</strong>
                <ul>
                  {result.result.analysis_summary.relevant_files.slice(0, 10).map((file, i) => (
                    <li key={i}><code>{file}</code></li>
                  ))}
                  {result.result.analysis_summary.relevant_files.length > 10 && (
                    <li>... and {result.result.analysis_summary.relevant_files.length - 10} more</li>
                  )}
                </ul>
              </div>
            </div>
          </section>
        )}
      </main>
    </div>
  );
}

export default DaedalusPage;
