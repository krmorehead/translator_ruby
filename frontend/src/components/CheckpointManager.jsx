import { useEffect, useState } from 'react';
import { useCheckpointStore } from '../store/checkpointStore';
import CheckpointList from './CheckpointList';
import CheckpointDiffViewer from './CheckpointDiffViewer';
import CreateCheckpointDialog from './CreateCheckpointDialog';
import RollbackConfirmDialog from './RollbackConfirmDialog';
import LoadingIndicator from './LoadingIndicator';
import './checkpoint.css';

function CheckpointManager() {
  const {
    checkpoints,
    currentCheckpoint,
    selectedCheckpoint,
    diff,
    loading,
    error,
    repositoryPath,
    setRepositoryPath,
    fetchCheckpoints,
    fetchCurrentCheckpoint,
    fetchCheckpointDiff,
    clearError,
    clearSelectedCheckpoint,
  } = useCheckpointStore();

  const [showCreateDialog, setShowCreateDialog] = useState(false);
  const [showRollbackDialog, setShowRollbackDialog] = useState(false);
  const [rollbackTarget, setRollbackTarget] = useState(null);
  const [pathInput, setPathInput] = useState('');

  useEffect(() => {
    if (repositoryPath) {
      fetchCheckpoints();
      fetchCurrentCheckpoint();
    }
  }, [repositoryPath, fetchCheckpoints, fetchCurrentCheckpoint]);

  const handleSetPath = () => {
    if (pathInput.trim()) {
      setRepositoryPath(pathInput.trim());
    }
  };

  const handleCheckpointSelect = async (checkpoint) => {
    if (currentCheckpoint) {
      await fetchCheckpointDiff(checkpoint.id, currentCheckpoint);
    }
  };

  const handleRollbackClick = (checkpoint) => {
    setRollbackTarget(checkpoint);
    setShowRollbackDialog(true);
  };

  const handleCreateSuccess = () => {
    setShowCreateDialog(false);
  };

  const handleRollbackSuccess = () => {
    setShowRollbackDialog(false);
    setRollbackTarget(null);
    clearSelectedCheckpoint();
  };

  const handleCloseDiff = () => {
    clearSelectedCheckpoint();
  };

  return (
    <div className="checkpoint-manager">
      <header className="checkpoint-header">
        <h1>Git Checkpoint Manager</h1>
        {error && (
          <div className="error-banner">
            <span>{error}</span>
            <button onClick={clearError} className="close-btn">×</button>
          </div>
        )}
      </header>

      {!repositoryPath ? (
        <div className="path-setup">
          <h2>Set Repository Path</h2>
          <div className="path-input-group">
            <input
              type="text"
              value={pathInput}
              onChange={(e) => setPathInput(e.target.value)}
              placeholder="/path/to/your/repository"
              className="path-input"
              onKeyPress={(e) => e.key === 'Enter' && handleSetPath()}
            />
            <button onClick={handleSetPath} className="btn-primary">
              Set Path
            </button>
          </div>
          <p className="help-text">
            Enter the full path to your Git repository to manage checkpoints
          </p>
        </div>
      ) : (
        <div className="checkpoint-content">
          <div className="checkpoint-toolbar">
            <div className="path-info">
              <strong>Repository:</strong> {repositoryPath}
              <button
                onClick={() => {
                  setRepositoryPath('');
                  setPathInput('');
                }}
                className="btn-link"
              >
                Change
              </button>
            </div>
            <div className="current-checkpoint">
              <strong>Current:</strong>{' '}
              <code>{currentCheckpoint || 'Loading...'}</code>
            </div>
            <button
              onClick={() => setShowCreateDialog(true)}
              className="btn-primary"
              disabled={loading}
            >
              + Create Checkpoint
            </button>
          </div>

          {loading && <LoadingIndicator />}

          <div className="checkpoint-panels">
            <div className="checkpoint-list-panel">
              <CheckpointList
                checkpoints={checkpoints}
                currentCheckpointId={currentCheckpoint}
                selectedCheckpoint={selectedCheckpoint}
                onCheckpointSelect={handleCheckpointSelect}
                onRollbackClick={handleRollbackClick}
              />
            </div>

            {diff && (
              <div className="checkpoint-diff-panel">
                <CheckpointDiffViewer
                  diff={diff}
                  onClose={handleCloseDiff}
                />
              </div>
            )}
          </div>
        </div>
      )}

      {showCreateDialog && (
        <CreateCheckpointDialog
          onClose={() => setShowCreateDialog(false)}
          onSuccess={handleCreateSuccess}
        />
      )}

      {showRollbackDialog && rollbackTarget && (
        <RollbackConfirmDialog
          checkpoint={rollbackTarget}
          onClose={() => {
            setShowRollbackDialog(false);
            setRollbackTarget(null);
          }}
          onSuccess={handleRollbackSuccess}
        />
      )}
    </div>
  );
}

export default CheckpointManager;








