module BattleGroup
  #
  # Employs probablistic solution based on density using a little linear
  # algebra.  During each round of the game a density matrix is built for
  # the individual pieces still in play by determining all possible positions
  # on the board that a piece can fit.  Each element in the matrix is a sum of
  # the # of times the piece could be positioned there in both orientations.  All
  # individual matrices are then summed up to provide an overall density picture.

  # While hunting the densest positions in the matrix are visited first.
  # If more than one position is found, a random sample is taken from the
  # set.  Once a hit is observed the targeting initially uses the density info
  # to order the adjacent cells to attack. After two or more hits, the algorithm
  # will favor vertical and horizontal targets based on the hit pattern.  If this can't
  # be determined (no single horizontal or vertical path) the density values
  # are again used to order target positions.
  #
  # 40 - 50 shot average per win (not emprical)
  #
  module ProbabilityTargeting
    attr_reader :matrix

    def next_coordinate
      @shot = next_target
    end

    def next_target
      if hunting?
        @matrix = build_matrix
        targets.sample(1).first
      else
        context.next_target
      end
    end

    def assess(intel)
      shots << @shot
      sunk(intel[:sunk]) if intel[:sunk]
      context.process intel
    end

    def build_matrix
      densities.map {|d| d.build_matrix(shots)}.reduce(Matrix.zero(10), :+)
    end

    def targets
      targets = []
      matrix.each_with_index do |val, row, col|
        targets << Coordinate.new(row, col) if val == matrix.max
      end
      targets
    end

    def densities
      @densities ||= [5, 4, 3, 3, 2].map {|len| PieceDensity.new(len)}
    end

    def sunk(length)
      densities.delete(
        densities.select {|d| d.length == length}.first
      )
    end

    def hunting?
      context.hunting?
    end

    def context
      @context ||= Context.new self
    end

    def shots
      @shots ||= []
    end

    class Context
      attr_reader :hits, :targets, :targeting, :hit_cnt, :sunk

      def initialize(targeting)
        @hit_cnt, @targeting = 0, targeting
        @hits, @targets, @sunk = [], [], []
      end

      def next_target
        targets.shift
      end

      def process(intel)
        if intel[:hit]
          @hit_cnt += 1
          hits << shot
          process_sunk(intel[:sunk]) if intel[:sunk]
          refine intel[:hit]         if targeting?
        end
        report intel
      end

      def process_sunk(len)
        (@sunk << len).sort!
        find_sunk(len).each {|c| hits.delete(c)}
        hunt if hits.empty?
      end

      def refine(hit)
        if hits_vertically_aligned?
          targets.unshift(next_vertical_targets).flatten!
          targets.sort!{|x,y| x.col == shot.col ? -1 : 1 }

        elsif hits_horizontally_aligned?
          targets.unshift(next_horizontal_targets).flatten!
          targets.sort!{|x,y| x.row == shot.row ? -1 : 1 }

        else
          targets.concat hits.last.adjacent.select{|c| valid_target? c}
          targets.sort! {|x, y| density(x) <=> density(y)}.reverse
        end
      end

      def next_vertical_targets
        sorted = hits.sort {|x, y| x.row <=> y.row}
        [sorted.first.up, sorted.last.down].select do |c|
          valid_target? c
        end
      end

      def next_horizontal_targets
        sorted = hits.sort {|x, y| x.col <=> y.col}
        [sorted.first.left, sorted.last.right].select do |c|
          valid_target? c
        end
      end

      def valid_target?(coord)
        coord.valid? && !shots.include?(coord) && !targets.include?(coord)
      end

      def hits_vertically_aligned?
        unless hits.count == 1
          hits.map(&:col).uniq.count == 1
        end
      end

      def hits_horizontally_aligned?
        unless hits.count == 1
          hits.map(&:row).uniq.count == 1
        end
      end

      def density(coord)
        matrix[coord.row, coord.col]
      end

      def find_sunk(len)
        [:up, :down, :right, :left].collect do |dir|
          (1...len).inject([hits.last]) {|c| c << c.last.send(dir)}
        end.select {|p| all_hits? p}.first
      end

      def all_hits?(coords)
        coords.reduce(true) {|m, c| m && hits.include?(c)}
      end

      def hunt
        hits.clear and targets.clear
      end

      def hunting?
        hits.empty?
      end

      def targeting?
        !hunting?
      end

      def matrix
        targeting.matrix
      end

      def shot
        shots.last
      end

      def shots
        targeting.shots
      end

      def report(intel)
        puts <<eos
\e[36m-------------------------------------------------------------\e[0m
            Targeting Info Game #{BattleGroup.battle.id} - Round #{shots.count}

 Targeting:        #{targeting?}
 Shot:             #{shot}
 Hit:              #{intel[:hit]}
 Sunk:             #{!!intel[:sunk]}
 Sunk Ships:       #{sunk}
 Hits:             #{hits}
 Targets:          #{targets}
 Hit Count:        #{hit_cnt}
 Miss Count:       #{shots.count - hit_cnt}
 Hit / Miss Ratio: #{((hit_cnt.to_f / shots.count.to_f)*100).to_i}%
 Shots Unique:     #{shots.count == shots.uniq.count}
 Shots Taken:      #{shots}
\e[36m-------------------------------------------------------------\e[0m
eos
      end
    end

    class PieceDensity
      attr_reader :length, :matrix, :shots

      def initialize(length)
        @length = length
      end

      def build_matrix(shots)
        @shots, @matrix = shots, Matrix.zero(10)
        Matrix.rows(rows) + Matrix.columns(cols)
      end

      def rows
        row = -1
        matrix.row_vectors.collect do |vector|
          row = row.next
          range.map do |col|
            if covers_shot? (col...col+length).map{|j| Coordinate.new row, j}
              zero_vector
            else
              build_vector col
            end
          end.reduce(vector, :+)
        end
      end

      def cols
        col = -1
        matrix.column_vectors.collect do |vector|
          col = col.next
          range.map do |row|
            if covers_shot? (row...row+length).map{|i| Coordinate.new i, col}
              zero_vector
            else
              build_vector row
            end
          end.reduce(vector, :+)
        end
      end

      def range
        (0..10 - length)
      end

      def covers_shot?(points)
        points.reduce(false) {|m, c| m || shots.include?(c)}
      end

      def build_vector(offset)
        Vector.elements (
          Array.new(offset, 0) + Array.new(length, 1) + Array.new(10 - offset - length, 0)
        )
      end

      def zero_vector
        Vector.elements Array.new(10, 0)
      end
    end
  end
end