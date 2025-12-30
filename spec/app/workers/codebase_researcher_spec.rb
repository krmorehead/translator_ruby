require 'rails_helper'

RSpec.describe CodebaseResearcher, type: :worker do
      let(:researcher) { CodebaseResearcher.new(goal: "test goal", path: "/tmp") }

  let(:nested_structure) { { is_leaf: false, id: 'root', children: [{ is_leaf: true, id: 'child1' }, { is_leaf: true, id: 'child2' }] } }
  let(:flat_structure) do
    [
      { text: "Child 1", parent_id: "root", metadata: { decomposition_id: "123", constraints: { depth: 3 } } },
      { text: "Child 2", parent_id: "root", metadata: { decomposition_id: "123", constraints: { depth: 3 } } }
    ]
  end
  let(:expected_metadata) { { decomposition_id: '123', constraints: { depth: 3 } } }

  describe '#execute' do
    context 'with valid decomposition' do
      it 'processes goal tree correctly' do
        flat_result = researcher.send(:convert_to_flat_structure, nested_structure)
        expect(flat_result).to be_an(Array)
        expect(flat_result.size).to eq(2)
      end

      it 'propagates metadata correctly' do
        workflow = double('GoalDecompositionWorkflow')
        allow(GoalDecompositionWorkflow).to receive(:new).and_return(workflow)
        allow(workflow).to receive(:setup)
        allow(workflow).to receive(:failed?).and_return(false)
        allow(workflow).to receive(:execute).and_return({ goal_tree: { metadata: expected_metadata } })
        allow(workflow).to receive(:result).and_return({ goal_tree: { metadata: expected_metadata } })
        allow(workflow).to receive(:complete?).and_return(true)
        allow(workflow).to receive(:leaf_goals).and_return([])

        researcher.execute
        expect(researcher.metadata[:decomposition_id]).to eq('123')
        expect(researcher.metadata[:constraints][:depth]).to eq(3)
      end
    end

    context 'with failed decomposition' do
      let(:failed_decomposition) { { error: "Failed to decompose" } }

      it 'handles errors gracefully' do
        allow(researcher).to receive(:decompose_goal).and_raise(StandardError, "Decomposition failed")
        result = researcher.execute
        expect(result[:success]).to be false
        expect(result[:error]).to match(/Decomposition failed/)
        expect(result[:metadata][:decomposition_status]).to eq("failed")
      end
    end
  end
end
