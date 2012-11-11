module BattleGroup
  module ProbabilityTargeting
    attr_reader :matrix

    def next_coordinate
      puts "shooting @ #{@shot = next_target}"
      @shot
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
      distributions.map {|d| d.matrix(shots)}.reduce(Matrix.zero(10), :+)
    end

    def targets
      find, targets = @matrix.max, []
      @matrix.each_with_index do |val, row, col|
        targets << Coordinate.new(row, col) if val == find
      end
      targets
    end

    def distributions
      @distirbutions ||= [5, 4, 3, 3, 2].map {|len| Distribution.new(len)}
    end

    def sunk(length)
      distributions.delete(
        distributions.select {|d| d.length == length}.first
      )
    end

    def hunting?
      context.hunting?
    end

    def context
      @context ||= TargetingContext.new self
    end

    def shots
      @shots ||= []
    end

    class TargetingContext
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
        puts "sunk #{len} on #{shots.last}"
        (@sunk << len).sort!.reverse
        find_sunk(len).each {|c| hits.delete(c)}
        hunt if hits.empty?
      end

      def refine(hit)
        if hits_vertically_aligned?
          targets.unshift(next_vertical_targets).flatten!
          # targets.concat(next_vertical_targets).flatten!
          # targets.sort! {|x, y| weight(x) <=> weight(y)}.reverse

        elsif hits_horizontally_aligned?
          targets.unshift(next_horizontal_targets).flatten!
          # targets.concat(next_horizontal_targets).flatten!
          # targets.sort! {|x, y| weight(x) <=> weight(y)}.reverse

        else
          coordinates = hits.last.adjacent.select{|c| valid_target? c}
          targets.concat coordinates
          targets.sort! {|x, y| weight(x) <=> weight(y)}.reverse
        end
      end

      def next_vertical_targets
        sorted, bounds = hits.sort {|x, y| x.row <=> y.row}, []
        up, down = sorted.first.up, sorted.last.down
        bounds << up   if valid_target? up
        bounds << down if valid_target? down
        bounds
      end

      def next_horizontal_targets
        sorted, bounds = hits.sort {|x, y| x.col <=> y.col}, []
        left, right = sorted.first.left, sorted.last.right
        bounds << left  if valid_target? left
        bounds << right if valid_target? right
        bounds
      end

      def valid_target?(coordinate)
        coordinate.valid? && !shots.include?(coordinate) && !targets.include?(coordinate)
      end

      def hits_vertically_aligned?
        return false if hits.count == 1 || hits.empty?
        hits.map(&:col).uniq.count == 1
      end

      def hits_horizontally_aligned?
        return false if hits.count == 1 || hits.empty?
        hits.map(&:row).uniq.count == 1
      end

      def weight(coordinate)
        matrix[coordinate.row, coordinate.col]
      end

      def find_sunk(len)
        [:up, :down, :right, :left].collect do |dir|
          (1...len).inject([hits.last]) {|c| c << c.last.send(dir)}
        end.select {|p| all_hits? p}.first
      end

      def all_hits?(coordinates)
        coordinates.reduce(true) {|m, c| m && hits.include?(c)}
      end

      def hunt
        hits.clear
        targets.clear
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

    class Distribution
      attr_accessor :length

      def initialize(length)
        @length = length
      end

      def matrix(shots)
        @shots, @matrix = shots, Matrix.zero(10)
        Matrix.rows(rows) + Matrix.columns(cols)
      end

      def rows
        row = -1
        @matrix.row_vectors.collect do |vector|
          row = row.next
          range.map do |col|
            if covers_shot? (col...col+length).map{|j| Coordinate.new row, j}
              Vector.elements Array.new(10, 0)
            else
              build_vector col
            end
          end.reduce(vector, :+)
        end
      end

      def cols
        col = -1
        @matrix.column_vectors.collect do |vector|
          col = col.next
          range.map do |row|
            if covers_shot? (row...row+length).map{|i| Coordinate.new i, col}
              Vector.elements Array.new(10, 0)
            else
              build_vector row
            end
          end.reduce(vector, :+)
        end
      end

      def range
        (0..10 - length)
      end

      def build_vector(offset)
        Vector.elements (
          Array.new(offset, 0) + Array.new(length, 1) + Array.new(10 - offset - length, 0)
        )
      end

      def covers_shot?(points)
        points.reduce(false) {|m, c| m || @shots.include?(c)}
      end
    end
  end
end