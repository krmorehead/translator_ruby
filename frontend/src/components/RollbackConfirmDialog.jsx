import { useState } from 'react';
import PropTypes from 'prop-types';
import { useCheckpointStore } from '../store/checkpointStore';

function RollbackConfirmDialog({ checkpoint, onClose, onSuccess }) {
  const { rollbackToCheckpoint, loading } = useCheckpointStore();
  const [force, setForce] = useState(false);
  const [error, setError] = useState('');

  const formatId = (id) => id.substring(0, 8);

  const handleConfirm = async () => {
    const success = await rollbackToCheckpoint(checkpoint.id, force);
    
    if (success) {
      onSuccess();
    } else {
      setError('Rollback failed. Try enabling force mode if you have uncommitted changes.');
    }
  };

  return (
    <div className="dialog-overlay" onClick={onClose}>
      <div className="dialog dialog-confirm" onClick={(e) => e.stopPropagation()}>
        <div className="dialog-header">
          <h2>⚠️ Confirm Rollback</h2>
          <button onClick={onClose} className="close-btn">×</button>
        </div>

        <div className="dialog-content">
          {error && <div className="error-message">{error}</div>}

          <div className="rollback-info">
            <p>
              You are about to rollback to checkpoint:
            </p>
            <div className="checkpoint-details">
              <div>
                <strong>ID:</strong> <code>{formatId(checkpoint.id)}</code>
              </div>
              <div>
                <strong>Message:</strong> {checkpoint.message}
              </div>
              <div>
                <strong>Created:</strong> {new Date(checkpoint.created_at).toLocaleString()}
              </div>
            </div>
          </div>

          <div className="warning-box">
            <strong>Warning:</strong> This will restore your repository to the state
            of this checkpoint. Any uncommitted changes will be lost unless you enable
            force mode.
          </div>

          <div className="form-group checkbox-group">
            <label>
              <input
                type="checkbox"
                checked={force}
                onChange={(e) => setForce(e.target.checked)}
                disabled={loading}
              />
              <span>
                Force rollback (override uncommitted changes)
              </span>
            </label>
          </div>

          <div className="dialog-actions">
            <button
              onClick={onClose}
              className="btn-secondary"
              disabled={loading}
            >
              Cancel
            </button>
            <button
              onClick={handleConfirm}
              className="btn-danger"
              disabled={loading}
            >
              {loading ? 'Rolling back...' : 'Confirm Rollback'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

RollbackConfirmDialog.propTypes = {
  checkpoint: PropTypes.shape({
    id: PropTypes.string.isRequired,
    message: PropTypes.string.isRequired,
    created_at: PropTypes.string.isRequired,
  }).isRequired,
  onClose: PropTypes.func.isRequired,
  onSuccess: PropTypes.func.isRequired,
};

export default RollbackConfirmDialog;

