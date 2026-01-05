# frozen_string_literal: true

# Singleton service managing the context graph.
# Provides unified API for querying context across workers, workflows, and memory stores
# using Dijkstra's shortest path algorithm with distance-based degradation.
class ContextGraphService
  include Singleton

  def initialize
    @nodes = {} # id => Node
    @edges = [] # Array of Edge objects
    @mutex = Mutex.new
  end

  # Register a memory store - called from MemoryStore#initialize
  def register_memory_store(store)
    @mutex.synchronize do
      node = Graph::WorkerNode.new(
        id: store.id,
        memory_store: store
      )
      @nodes[store.id] = node
    end
  end

  # Register a workflow memory store - called from WorkflowMemoryStore#initialize
  # Automatically creates edges to parent memory
  def register_workflow_memory_store(store)
    @mutex.synchronize do
      node = Graph::WorkflowNode.new(
        id: store.workflow_id,
        workflow_memory: store
      )
      @nodes[store.workflow_id] = node

      # Automatically create edge to parent if exists
      if store.parent_memory
        parent_id = if store.parent_memory.respond_to?(:workflow_id)
          # Parent is a WorkflowMemoryStore
          store.parent_memory.workflow_id
        elsif store.parent_memory.respond_to?(:id)
          # Parent is a MemoryStore or ResearchMemoryStore
          store.parent_memory.id
        end

        if parent_id
          edge = Graph::Edges::ParentChildEdge.new(
            from_node_id: store.workflow_id,
            to_node_id: parent_id,
            metadata: { relationship: :workflow_to_parent }
          )
          @edges << edge
        end
      end
    end
  end

  # Register a node in the graph
  # @param node [Graph::Node] Node to register
  # @raise [TypeError] If node is not a Graph::Node
  def register_node(node)
    raise TypeError, "node must be a Graph::Node, got #{node.class}" unless node.is_a?(Graph::Node)

    @mutex.synchronize do
      @nodes[node.id] = node
    end
  end

  # Create an edge between nodes
  # @param edge [Graph::Edge] Edge to add
  # @raise [TypeError] If edge is not a Graph::Edge
  def add_edge(edge)
    raise TypeError, "edge must be a Graph::Edge, got #{edge.class}" unless edge.is_a?(Graph::Edge)

    @mutex.synchronize do
      @edges << edge
    end
  end

  # Find a node by ID
  # @param id [String] Node ID to lookup
  # @return [Graph::Node, nil] The node if found, nil otherwise
  def find_by_id(id)
    @mutex.synchronize do
      @nodes[id.to_s]
    end
  end

  # Find all nodes by owner_id
  # @param owner_id [String] Owner ID to search for
  # @return [Array<Graph::Node>] Array of nodes belonging to this owner
  def find_by_owner(owner_id)
    @mutex.synchronize do
      @nodes.values.select do |node|
        node.metadata[:owner_id] == owner_id.to_s
      end
    end
  end

  # Main query interface - scoped to node id
  # @param id [String] Starting point for graph traversal (the node querying)
  # @param context_type [Symbol] Type of context to retrieve (:goal, :decision, etc)
  # @param query_vector [Embedding, String] Vector or text to search with
  # @param threshold [Float] Similarity threshold (0.0-1.0)
  # @param edge_types [Array<Symbol>, nil] Filter to specific edge types (nil = all)
  # @param limit [Integer, nil] Max results to return (nil = all)
  # @return [Array<Hash>] Array of {memory:, similarity:, final_score:, path_distance:, source:, path:}
  # Query the graph for relevant context
  # @param id [String] Starting node ID
  # @param context_type [Symbol] Type of context to query
  # @param query_embedding [Embedding] Query embedding (required, must be Embedding object)
  # @param threshold [Float] Similarity threshold
  # @param edge_types [Array<Symbol>, nil] Optional edge type filters
  # @param limit [Integer, nil] Optional result limit
  # @return [Array<Hash>] Relevant context entries
  def query(id:, context_type:, query_embedding:, threshold: 0.7, edge_types: nil, limit: nil)
    raise TypeError, "query_embedding must be an Embedding, got #{query_embedding.class}" unless query_embedding.is_a?(Embedding)
    
    @mutex.synchronize do
      node = @nodes[id.to_s]
      return [] unless node

      # Find shortest paths using Dijkstra with optional edge filtering
      shortest_paths = dijkstra_shortest_paths(
        start_node_id: id.to_s,
        edge_types: edge_types
      )

      # Calculate max distance before perfect match falls below threshold
      max_distance = calculate_max_distance(threshold)

      # Query each reachable node within distance limit
      results = []
      shortest_paths.each do |node_id, path_info|
        distance = path_info[:distance]

        # Early termination: if distance too great, even perfect match won't qualify
        degradation = calculate_degradation(distance)
        break if degradation < threshold

        target_node = @nodes[node_id]
        next unless target_node

        # Delegate query to node (returns [{memory:, similarity:, source:}])
        node_results = target_node.query_context(
          context_type: context_type,
          query_embedding: query_embedding,
          threshold: 0.0  # We'll apply threshold after degradation
        )

        # Apply distance degradation to similarity scores
        node_results.each do |result|
          final_score = result[:similarity] * degradation
          if final_score >= threshold
            results << result.merge(
              final_score: final_score,
              path_distance: distance,
              degradation: degradation,
              path: path_info[:path].map(&:edge_type)
            )
          end
        end
      end

      # Sort by final score (highest first), apply limit if specified
      sorted = results.sort_by { |r| -r[:final_score] }
      limit ? sorted.first(limit) : sorted
    end
  end

  # Remove a node and its edges (for cleanup)
  # @param node_id [String] ID of node to remove
  def unregister_node(node_id)
    @mutex.synchronize do
      @nodes.delete(node_id.to_s)
      @edges.reject! { |e| e.from_node_id == node_id.to_s || e.to_node_id == node_id.to_s }
    end
  end

  # Get all registered nodes (for debugging)
  # @return [Array<Graph::Node>] All nodes in the graph
  def nodes
    @mutex.synchronize { @nodes.values.dup }
  end

  # Get all edges (for debugging)
  # @return [Array<Graph::Edge>] All edges in the graph
  def edges
    @mutex.synchronize { @edges.dup }
  end

  private

  # Dijkstra's algorithm for shortest paths with optional edge type filtering.
  # Returns shortest path from start_node_id to all reachable nodes.
  #
  # @param start_node_id [String] Starting node ID
  # @param edge_types [Array<Symbol>, nil] Filter to specific edge types
  # @return [Hash] {node_id => {distance:, path: [edges]}}
  def dijkstra_shortest_paths(start_node_id:, edge_types: nil)
    distances = { start_node_id => 0 }
    paths = { start_node_id => [] }
    unvisited = Set.new(@nodes.keys)

    while unvisited.any?
      # Find unvisited node with smallest distance
      current = unvisited.min_by { |id| distances[id] || Float::INFINITY }
      current_distance = distances[current]

      # If current node is unreachable, we're done
      break if current_distance.nil? || current_distance == Float::INFINITY

      unvisited.delete(current)

      # Find outgoing edges, optionally filtered by type
      outgoing = @edges.select { |e| e.from_node_id == current }
      outgoing = outgoing.select { |e| edge_types.include?(e.edge_type) } if edge_types

      outgoing.each do |edge|
        neighbor = edge.to_node_id
        next unless unvisited.include?(neighbor)

        # Distance = number of hops (edges), not weighted by edge properties
        new_distance = current_distance + 1

        if distances[neighbor].nil? || new_distance < distances[neighbor]
          distances[neighbor] = new_distance
          paths[neighbor] = paths[current] + [edge]
        end
      end
    end

    # Return only reachable nodes (exclude INFINITY distance)
    distances.each_with_object({}) do |(node_id, distance), result|
      next if distance == Float::INFINITY
      result[node_id] = { distance: distance, path: paths[node_id] }
    end
  end

  # Calculate distance degradation factor.
  # Formula: 1.0 / (1.0 + distance * 0.3)
  #
  # @param distance [Integer] Number of hops from starting node
  # @return [Float] Degradation factor (0.0-1.0)
  def calculate_degradation(distance)
    1.0 / (1.0 + distance * 0.3)
  end

  # Calculate maximum distance where perfect match (1.0) would meet threshold.
  # Solves: threshold = 1.0 / (1.0 + distance * 0.3)
  #
  # @param threshold [Float] Minimum similarity threshold
  # @return [Integer] Maximum distance to search
  def calculate_max_distance(threshold)
    return Float::INFINITY if threshold <= 0.0
    ((1.0 / threshold - 1.0) / 0.3).ceil
  end
end
