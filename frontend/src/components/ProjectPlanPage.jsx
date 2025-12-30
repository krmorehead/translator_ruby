import { useProjectPlanStore } from "../store/projectPlanStore";
import PlanViewer from "./PlanViewer";
import LoadingIndicator from "./LoadingIndicator";
import "./project-plan.css";

function ProjectPlanPage() {
  const goal = useProjectPlanStore((state) => state.goal);
  const path = useProjectPlanStore((state) => state.path);
  const projectName = useProjectPlanStore((state) => state.projectName);
  const loading = useProjectPlanStore((state) => state.loading);
  const error = useProjectPlanStore((state) => state.error);
  const result = useProjectPlanStore((state) => state.result);
  
  const setGoal = useProjectPlanStore((state) => state.setGoal);
  const setPath = useProjectPlanStore((state) => state.setPath);
  const setProjectName = useProjectPlanStore((state) => state.setProjectName);
  const createPlan = useProjectPlanStore((state) => state.createPlan);
  const reset = useProjectPlanStore((state) => state.reset);

  const handleSubmit = (e) => {
    e.preventDefault();
    createPlan();
  };

  return (
    <div className="project-plan-page">
      <header className="plan-header">
        <div className="header-content">
          <p className="eyebrow">Project Planner</p>
          <h1>Create Project Plan</h1>
          <p className="subtitle">Generate structured project plans from codebase research</p>
        </div>
        {loading && <LoadingIndicator />}
      </header>

      <main className="plan-main">
        <section className="plan-form-section">
          <form onSubmit={handleSubmit} className="plan-form">
            <div className="form-group">
              <label htmlFor="goal">Project Goal</label>
              <textarea
                id="goal"
                value={goal}
                onChange={(e) => setGoal(e.target.value)}
                placeholder="Describe what you want to build or accomplish..."
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
              <label htmlFor="projectName">Project Name</label>
              <input
                type="text"
                id="projectName"
                value={projectName}
                onChange={(e) => setProjectName(e.target.value)}
                placeholder="my_new_feature"
                disabled={loading}
              />
              <small>Used for directory naming (will be slugified)</small>
            </div>

            <div className="form-actions">
              <button 
                type="submit" 
                className="btn-primary"
                disabled={loading || !goal || !path || !projectName}
              >
                {loading ? "Planning..." : "Generate Plan"}
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
            <PlanViewer
              milestones={result.milestones || []}
              fileReferencesPath={result.file_references_path}
              projectPlanPath={result.project_plan_path}
              projectPath={result.project_path}
              researchSummary={result.research_summary}
              existingFiles={result.existing_files || []}
              plannedFiles={result.planned_files || []}
            />
          </section>
        )}
      </main>
    </div>
  );
}

export default ProjectPlanPage;

