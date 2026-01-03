import PropTypes from 'prop-types';

function CheckpointList({
  checkpoints,
  currentCheckpointId,
  selectedCheckpoint,
  onCheckpointSelect,
  onRollbackClick,
}) {
  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(date);
  };

  const formatId = (id) => {
    return id.substring(0, 8);
  };

  if (!checkpoints || checkpoints.length === 0) {
    return (
      <div className="checkpoint-list-empty">
        <p>No checkpoints found</p>
        <p className="help-text">Create your first checkpoint to get started</p>
      </div>
    );
  }

  return (
    <div className="checkpoint-list">
      <h2>Checkpoints ({checkpoints.length})</h2>
      <div className="checkpoint-items">
        {checkpoints.map((checkpoint) => {
          const isCurrent = checkpoint.id === currentCheckpointId;
          const isSelected = selectedCheckpoint && selectedCheckpoint.id === checkpoint.id;

          return (
            <div
              key={checkpoint.id}
              className={`checkpoint-item ${isCurrent ? 'current' : ''} ${isSelected ? 'selected' : ''}`}
              onClick={() => onCheckpointSelect(checkpoint)}
            >
              <div className="checkpoint-header-row">
                <code className="checkpoint-id">{formatId(checkpoint.id)}</code>
                {isCurrent && <span className="badge current-badge">CURRENT</span>}
                {checkpoint.is_backup && <span className="badge backup-badge">BACKUP</span>}
              </div>

              <div className="checkpoint-message">{checkpoint.message}</div>

              <div className="checkpoint-meta">
                <span className="checkpoint-date">{formatDate(checkpoint.created_at)}</span>
                <span className="checkpoint-files">
                  {checkpoint.files_changed} {checkpoint.files_changed === 1 ? 'file' : 'files'}
                </span>
              </div>

              {checkpoint.execution_id && (
                <div className="checkpoint-metadata">
                  <span className="metadata-label">Execution:</span>
                  <code>{formatId(checkpoint.execution_id)}</code>
                </div>
              )}

              {checkpoint.milestone_id && (
                <div className="checkpoint-metadata">
                  <span className="metadata-label">Milestone:</span>
                  <code>{formatId(checkpoint.milestone_id)}</code>
                </div>
              )}

              {!isCurrent && (
                <div className="checkpoint-actions">
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onRollbackClick(checkpoint);
                    }}
                    className="btn-secondary btn-small"
                  >
                    ← Rollback
                  </button>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

CheckpointList.propTypes = {
  checkpoints: PropTypes.arrayOf(
    PropTypes.shape({
      id: PropTypes.string.isRequired,
      message: PropTypes.string.isRequired,
      created_at: PropTypes.string.isRequired,
      files_changed: PropTypes.number,
      execution_id: PropTypes.string,
      milestone_id: PropTypes.string,
      is_backup: PropTypes.bool,
    })
  ).isRequired,
  currentCheckpointId: PropTypes.string,
  selectedCheckpoint: PropTypes.object,
  onCheckpointSelect: PropTypes.func.isRequired,
  onRollbackClick: PropTypes.func.isRequired,
};

export default CheckpointList;








