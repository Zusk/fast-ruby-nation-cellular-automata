require 'set'

class CellularAutomata
  # Constants for Configuration
  GROWTH_RATE = 1
  INIT_POPULATION_COUNT = 10
  BOARD_SIZE = 50
  CHUNK_SIZE = 10
  NUM_CHUNKS = (BOARD_SIZE / CHUNK_SIZE).ceil
  SHOW_LOGS = false
  ITERATIONS = 350000
  DISPLAY_SEQUENTIALLY = true
  WEIGHT_ADJUSTMENT = 100.0
  ORTHOGONAL_DIRECTIONS = [[-1, 0], [1, 0], [0, -1], [0, 1]]
  FACTION_COUNT = 9  # Number of factions to be spawned
  
  def self.generate_random_color
    "\e[38;2;#{rand(256)};#{rand(256)};#{rand(256)}m██\e[0m"
  end

  STARTING_COLOR_ARRAY = Array.new(FACTION_COUNT) { generate_random_color }
  
  # List of all Factions selected from the STARTING_COLOR_ARRAY based on FACTION_COUNT
  FACTIONS = STARTING_COLOR_ARRAY[0...FACTION_COUNT]
  
  # FACTIONS is an array, so let's create a hash for O(1) checks
  FACTIONS_HASH = FACTIONS.each_with_object({}) { |faction, hsh| hsh[faction] = true }

  EMPTY = ". "
  
  # Initialize the Cellular Automata board and setup the initial cells
  def initialize
    initialize_chunks
    @capitals = {}  # Dictionary to store the capitals for each faction
    @frontier_tiles = {}  # Dictionary to store the frontier tiles for each faction
    @total_tiles = {}  # Dictionary to store the total tiles for each faction
    # Initialize the frontier tiles dictionary for each faction
    FACTIONS.each do |faction|
      @frontier_tiles[faction] = Set.new
      @total_tiles[faction] = Set.new
    end
    populate_initial_cells
    @frame_count = 0  # Initialize frame count
  end

def populate_initial_cells
  # Calculate the number of rows and columns for the grid based on the number of factions
  rows = Math.sqrt(FACTIONS.size).ceil
  cols = (FACTIONS.size.to_f / rows).ceil

  # Calculate the dimensions for each section of the board
  section_width = BOARD_SIZE / cols
  section_height = BOARD_SIZE / rows

  # Loop through each section and spawn the initial population for each faction
  FACTIONS.each_with_index do |faction, index|
    col = index % cols
    row = index / cols

    # Calculate the center of the current section
    spawn_x = (row * section_height) + (section_height / 2)
    spawn_y = (col * section_width) + (section_width / 2)

    # Spawn the initial population around the center of the section
    INIT_POPULATION_COUNT.times do
      x_offset, y_offset = spawn_x + rand(-2..2), spawn_y + rand(-2..2)
      
      # Setting the cell value in the chunk
      set_cell(x_offset, y_offset, faction)
      
      # Update the total_tiles dictionary
      @total_tiles[faction].add([x_offset, y_offset])

      # Directly add each new tile to the frontier tiles set
      @frontier_tiles[faction].add([x_offset, y_offset])
    end
  end
end


  def initialize_chunks
    @chunks = Array.new(NUM_CHUNKS) do
      Array.new(NUM_CHUNKS) do
        Array.new(CHUNK_SIZE) { Array.new(CHUNK_SIZE, EMPTY) }
      end
    end
  end

  def get_cell(x, y)
    chunk_x, chunk_y, inner_x, inner_y = coordinates_for_chunk(x, y)
    @chunks[chunk_x][chunk_y][inner_x][inner_y]
  end

  def set_cell(x, y, value)
    chunk_x, chunk_y, inner_x, inner_y = coordinates_for_chunk(x, y)
    @chunks[chunk_x][chunk_y][inner_x][inner_y] = value
  end

  def coordinates_for_chunk(x, y)
    [x / CHUNK_SIZE, y / CHUNK_SIZE, x % CHUNK_SIZE, y % CHUNK_SIZE]
  end
  
# Display the current state of the board
def display_board
  # Increment the frame count at the beginning
  @frame_count += 1

  # Return if not a 10th frame
  return unless @frame_count % 5000 == 0

  puts "Tick: #{@frame_count}"

  # Generate the board as a single string
  board_str = ""
  @chunks.each do |chunk_row|
    CHUNK_SIZE.times do |i|
      chunk_row.each do |chunk|
        board_str += chunk[i].map do |cell|
          if cell == EMPTY
            EMPTY
          elsif FACTIONS_HASH[cell]  # Check if the cell is a faction using the hash
            cell + ''  # Display the colored '#' character
          else
            "?"  # Placeholder for unrecognized cell values
          end
        end.join
      end
      board_str += "\n"
    end
  end

  # Display logic
  if DISPLAY_SEQUENTIALLY
    # Clear the terminal at the beginning of the animation
    clear_terminal if @frame_count == 5000
    
    # Move the cursor to the top-left corner of the terminal
    print "\e[H"
    
    # Print the board
    print board_str
    
    # Move the cursor to the bottom-right corner of the board
    print "\e[#{BOARD_SIZE + 2};1H"
  else
    # Clear the terminal for every 10th frame
    clear_terminal
    
    # Print the board
    puts board_str
  end
end



  # Clear the terminal screen
  def clear_terminal
    system("clear") # Works for Linux and macOS
  end
  
# Count the neighbors of a cell at position (x, y) that belong to a specific faction
def count_neighbors(x, y, faction)
  neighbors = [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]]
  count = 0
  neighbors.each do |dx, dy|
    nx, ny = x + dx, y + dy

    # Check if the global position is valid
    if valid_position?(nx, ny)
      # Get the chunk and local indices
      chunk_x, chunk_y, local_x, local_y = global_to_chunk_and_local_indices(nx, ny)

      # Access the chunk and then the cell within that chunk
      cell_value = @chunks[chunk_x][chunk_y][local_x][local_y]

      # Check if the cell's value matches the specified faction
      if cell_value == EMPTY || cell_value == faction
        count += 1
      end
    end
  end
  count
end

def global_to_chunk_and_local_indices(global_x, global_y)
  chunk_x = global_x / CHUNK_SIZE
  chunk_y = global_y / CHUNK_SIZE
  local_x = global_x % CHUNK_SIZE
  local_y = global_y % CHUNK_SIZE

  [chunk_x, chunk_y, local_x, local_y]
end


def grow_cell(x, y, faction)
  # Calculate the probability of a cell growing based on the growth rate 
  # and the number of neighboring cells of the same faction.
  growth_probability = GROWTH_RATE + 2 * count_neighbors(x, y, faction)

  # Exit the function if a random number between 0 and 100 is greater than or equal 
  # to the calculated growth probability.
  return unless rand(100) < growth_probability


  # Generate potential positions for the cell to grow into based on its orthogonal neighbors.
  valid_positions = ORTHOGONAL_DIRECTIONS.map { |dx, dy| [x + dx, y + dy] }
                                          .select { |nx, ny| valid_position?(nx, ny) }

  # Calculate the number of neighbors for each potential position.
  neighbor_counts = valid_positions.map do |new_x, new_y|
    chunk_x, chunk_y, local_x, local_y = global_to_chunk_and_local_indices(new_x, new_y)
    cell_value = @chunks[chunk_x][chunk_y][local_x][local_y]
    
    (cell_value == EMPTY || cell_value != faction) ? count_neighbors(new_x, new_y, faction) : 0
  end

  # Exit the function if none of the potential positions have neighbors.
  return if neighbor_counts.reduce(:+) == 0

  # Adjust the neighbor counts using the WEIGHT_ADJUSTMENT constant. 
  probabilities = neighbor_counts.map { |count| count**WEIGHT_ADJUSTMENT }
  total = probabilities.reduce(:+)
  probabilities.map! { |prob| prob / total }

  # Select a direction for the cell to grow into based on the adjusted probabilities.
  direction = valid_positions[sample_weighted(probabilities)]
  new_x, new_y = direction
  
  # Calculate chunk and local indices for the new position
  chunk_x, chunk_y, local_x, local_y = global_to_chunk_and_local_indices(new_x, new_y)

  # If the selected position is empty or belongs to a different faction:
  if @chunks[chunk_x][chunk_y][local_x][local_y] == EMPTY || @chunks[chunk_x][chunk_y][local_x][local_y] != faction
    # If the position is a capital of another faction, update or remove the capital.
    if @capitals.values.include?([new_x, new_y])
      lost_faction = @chunks[chunk_x][chunk_y][local_x][local_y]
      if @total_tiles[lost_faction].size > 0
        @capitals[lost_faction] = @total_tiles[lost_faction].to_a.sample
      else
        @capitals.delete(lost_faction)
      end
    end

    # Update the total tiles to reflect the cell's growth.
    @total_tiles[@chunks[chunk_x][chunk_y][local_x][local_y]].delete([new_x, new_y]) if @chunks[chunk_x][chunk_y][local_x][local_y] != EMPTY
    @chunks[chunk_x][chunk_y][local_x][local_y] = faction
    @total_tiles[faction].add([new_x, new_y])
  end

  # Update the frontier status of the cell and its neighbors.
  tiles_to_update = [[x, y]] + valid_positions
  tiles_to_update.each { |tx, ty| update_frontier_tile(tx, ty) }
end



# Sample index based on weighted probabilities.
# This helper function selects an index from a list based on provided weighted probabilities.
def sample_weighted(probabilities)
  sum = 0.0
  target = rand
  probabilities.each_with_index do |prob, index|
    sum += prob
    return index if sum > target
  end
  probabilities.size - 1
end

# Update frontier status for a specific tile
def update_frontier_tile(x, y)
  # Determine the chunk and local indices for the given coordinates
  chunk_x, chunk_y, local_x, local_y = global_to_chunk_and_local_indices(x, y)

  # Check if the tile coordinates are within the board's boundaries
  return unless x.between?(0, BOARD_SIZE - 1) && y.between?(0, BOARD_SIZE - 1)

  cell = @chunks[chunk_x][chunk_y][local_x][local_y]

  # Check if the cell belongs to one of the factions
  return unless FACTIONS_HASH[cell]

  # Check if the tile is a frontier tile
  is_edge = ORTHOGONAL_DIRECTIONS.any? do |dx, dy|
    neighbor_x, neighbor_y = x + dx, y + dy
    return unless valid_position?(neighbor_x, neighbor_y)

    # Get the chunk and local indices for the neighbor
    neighbor_chunk_x, neighbor_chunk_y, neighbor_local_x, neighbor_local_y = global_to_chunk_and_local_indices(neighbor_x, neighbor_y)

    # Get the cell value of the neighbor
    neighbor_cell = @chunks[neighbor_chunk_x][neighbor_chunk_y][neighbor_local_x][neighbor_local_y]

    # Check the frontier condition
    neighbor_cell == EMPTY || (FACTIONS_HASH[neighbor_cell] && neighbor_cell != cell)
  end

  # Update the frontier tiles list
  if is_edge
    @frontier_tiles[cell].add([x, y])
  else
    @frontier_tiles[cell].delete([x, y])
  end
end



# Determines if a given position (x, y) lies within the board boundaries.
# Checks are performed using direct comparisons for performance reasons,
# as this method can be called very frequently.
#
# @param x [Integer] The x-coordinate of the position.
# @param y [Integer] The y-coordinate of the position.
# @return [Boolean] Returns true if the position is within the board boundaries, false otherwise.
UPPER_BOUND = BOARD_SIZE - 1

def valid_position?(x, y)
  x >= 0 && x <= UPPER_BOUND && y >= 0 && y <= UPPER_BOUND
end



# Drive the evolution of cells over time
def run
    total_board_tiles = BOARD_SIZE * BOARD_SIZE
    years = 0  # Initialize the year count to 0

    # Constants for max caps
    @MAX_ITERATIONS_CHANGE_LOW = 15
    @MAX_ITERATIONS_CHANGE_HIGH = 30

    # Calculate @iterations_change_low and @iterations_change_high based on board size
    base_value = BOARD_SIZE * 0.05
    @iterations_change_low = [base_value.to_i, @MAX_ITERATIONS_CHANGE_LOW].min
    @iterations_change_high = [(base_value * 2).to_i, @MAX_ITERATIONS_CHANGE_HIGH].min

    ITERATIONS.times do |i|
        # A number of times equal to rand(@iterations_change_low...@iterations_change_high)
        rand(@iterations_change_low...@iterations_change_high).times do
            faction = FACTIONS.sample  # Select a random faction
            tiles_to_process = @frontier_tiles[faction].to_a.sample(rand(3))  # Select a random sample from its edge list

            tiles_to_process.each do |x, y|
                grow_cell(x, y, faction)
            end
        end

        # Display logic
        if (i + 1) % 12 == 0
            years += 1  # Increment the year count
            #puts "Year: #{years}"
        end
        display_board if DISPLAY_SEQUENTIALLY || (i == ITERATIONS - 1)
    end
end

end

#RubyProf.start

# Your code to profile
#sim = CellularAutomata.new
#sim.run

#result = RubyProf.stop
#printer = RubyProf::FlatPrinter.new(result)
#printer.print(STDOUT)

# Create an instance of the CellularAutomata class and run it
sim = CellularAutomata.new

start_time = Time.now  # Record the start time

print "\e[?25l"
sim.run
print "\e[?25h"

end_time = Time.now  # Record the end time

runtime_in_milliseconds = ((end_time - start_time) * 1000).round

puts "TOTAL RUNTIME: #{runtime_in_milliseconds}ms"
