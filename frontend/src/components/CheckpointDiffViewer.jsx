import PropTypes from 'prop-types';

function CheckpointDiffViewer({ diff, onClose }) {
  if (!diff) return null;

  const { summary, changes, from_checkpoint_id, to_checkpoint_id } = diff;

  const formatId = (id) => id.substring(0, 8);

  const getChangeTypeLabel = (change) => {
    if (change.added_lines > 0 && change.deleted_lines > 0) return 'modified';
    if (change.added_lines > 0) return 'added';
    if (change.deleted_lines > 0) return 'deleted';
    return 'unchanged';
  };

  const getChangeTypeClass = (change) => {
    const type = getChangeTypeLabel(change);
    return `change-type-${type}`;
  };

  return (
    <div className="diff-viewer">
      <div className="diff-viewer-header">
        <h2>Checkpoint Diff</h2>
        <button onClick={onClose} className="close-btn">×</button>
      </div>

      <div className="diff-comparison">
        <div>
          <strong>From:</strong> <code>{formatId(from_checkpoint_id)}</code>
        </div>
        <div>
          <strong>To:</strong> <code>{formatId(to_checkpoint_id)}</code>
        </div>
      </div>

      <div className="diff-summary">
        <div className="summary-item added">
          <strong>+{summary.files_added}</strong> added
        </div>
        <div className="summary-item modified">
          <strong>{summary.files_modified}</strong> modified
        </div>
        <div className="summary-item deleted">
          <strong>-{summary.files_deleted}</strong> deleted
        </div>
        <div className="summary-item total">
          <strong>{summary.total_changes}</strong> total changes
        </div>
      </div>

      <div className="diff-changes">
        <h3>Changed Files</h3>
        {changes && changes.length > 0 ? (
          <div className="changes-list">
            {changes.map((change, index) => (
              <div
                key={index}
                className={`change-item ${getChangeTypeClass(change)}`}
              >
                <div className="change-header">
                  <code className="file-path">{change.file_path}</code>
                  <span className={`change-badge ${getChangeTypeLabel(change)}`}>
                    {getChangeTypeLabel(change)}
                  </span>
                </div>

                <div className="change-stats">
                  {change.added_lines > 0 && (
                    <span className="stat-added">+{change.added_lines}</span>
                  )}
                  {change.deleted_lines > 0 && (
                    <span className="stat-deleted">-{change.deleted_lines}</span>
                  )}
                </div>

                {change.diff_preview && (
                  <pre className="diff-preview">
                    <code>{change.diff_preview}</code>
                  </pre>
                )}
              </div>
            ))}
          </div>
        ) : (
          <p className="no-changes">No file changes</p>
        )}
      </div>
    </div>
  );
}

CheckpointDiffViewer.propTypes = {
  diff: PropTypes.shape({
    from_checkpoint_id: PropTypes.string.isRequired,
    to_checkpoint_id: PropTypes.string.isRequired,
    changes: PropTypes.arrayOf(
      PropTypes.shape({
        file_path: PropTypes.string.isRequired,
        added_lines: PropTypes.number.isRequired,
        deleted_lines: PropTypes.number.isRequired,
        diff_preview: PropTypes.string,
      })
    ),
    summary: PropTypes.shape({
      files_added: PropTypes.number.isRequired,
      files_modified: PropTypes.number.isRequired,
      files_deleted: PropTypes.number.isRequired,
      total_changes: PropTypes.number.isRequired,
    }).isRequired,
  }),
  onClose: PropTypes.func.isRequired,
};

export default CheckpointDiffViewer;








