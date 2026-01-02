# frozen_string_literal: true

module Actions
  # Action that wraps InventoryTool for inventory management
  class ManageInventoryAction < BaseAction
    def execute(action:, item:, quantity: 1)
      tool = InventoryTool.new
      result = tool.execute(
        operation: action,
        item_name: item,
        quantity: quantity
      )
      
      return error_result(result[:error]) unless result[:success]
      
      summary = case action
                when "add" then "Added #{quantity} #{item} to inventory"
                when "remove" then "Removed #{quantity} #{item} from inventory"
                when "check" then "Checked inventory for #{item}"
                else "Inventory action: #{action}"
                end
      
      success_result(result[:result], summary: summary)
    end
  end
end
