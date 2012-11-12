$LOAD_PATH << Dir.pwd

require 'json'
require 'matrix'
require 'net/http'
require 'uri'
require 'algos/adjacent_targeting'
require 'algos/probability_targeting'

#
# Contains all of the classes/collaborators that make up the basis
# for the solution.
#
module BattleGroup
  class << self
    attr_reader :name, :fleet, :com, :battle

    def general_quarters(fleet = Board.generate, address = 'http://localhost:3000')
      @name   = "WHISKEY-TANGO-#{rand(100)}"
      @fleet  = fleet
      @com    = CommunicationsOfficer.new(address)
      @battle = Battle.new(com.join[:game_id])

      puts "Playing as #{@name}.  Waiting for opponent."
      OperationsOfficer.new.begin_offensive
    end
  end

  #
  # Battle context
  #
  class Battle
    attr_reader :id, :status, :my_turn
    alias :my_turn? :my_turn

    def initialize(id)
      @id, @status = id, :playing
    end

    def update(status)
      @status, @my_turn = status[:game_status].to_sym, status[:my_turn]
    end

    def over?
      status != :playing
    end

    def won?
      status == :won
    end
  end

  #
  # Manages the game flow
  #
  class OperationsOfficer
    def begin_offensive
      com, battle = BattleGroup.com, BattleGroup.battle
      until battle.over?
        fire if battle.my_turn?
        battle.update(com.status)
        sleep 0.1
      end

      debrief
    end

    def fire
      intel = BattleGroup.com.fire(cic.next_coordinate)
      cic.assess intel
    end

    def debrief
      battle = BattleGroup.battle
      puts msg = if battle.won?
        "Congratulations sir! You won in #{cic.shots.count} shots."
      else
        "You lost Ensign, need to upgrade your tactics son!"
      end
    end

    def cic
      @cic ||= CombatInformationCenter.new
    end
  end

  #
  # Manages the targeting sub system.  Different targeting algos can
  # be plugged in.  These algos simply need to provide an implementation
  # of next_target, that returns a Coordinate, and optionally refine to
  # provide the algo with the current state of the shots.
  #
  class CombatInformationCenter
    include ProbabilityTargeting
    # include AdjacentTargeting
  end

  #
  # Http and game protocol handler.
  #
  class CommunicationsOfficer
    def initialize(address)
      uri   = URI.parse(address)
      @http = Net::HTTP.new(uri.host, uri.port)
    end

    def join
      post '/games/join', user: user, board: board
    end

    def status
      get '/games/status', user: user, game_id: game_id
    end

    def fire(coordinate)
      post '/games/fire', user: user, game_id: game_id, shot: coordinate
    end

    def get(path, data)
      params = data.map{|k,v| "#{k}=#{v}"}.join('&')
      request Net::HTTP::Get.new("#{path}?#{params}")
    end

    def post(path, data)
      post = Net::HTTP::Post.new(path)
      post.set_form_data(data)
      request post
    end

    def request(request)
      response = @http.request(request).body
      JSON.parse(response, symbolize_names: true)
    end

    def user
      BattleGroup.name
    end

    def game_id
      BattleGroup.battle.id
    end

    def board
      BattleGroup.fleet
    end
  end

  #
  # Generates a random board.
  #
  class Board
    attr_reader :cells

    def self.generate
      self.new.random
    end

    def initialize
      @cells = Array.new(10).map! {Array.new(10, '')}
    end

    def random
      [5, 4, 3, 3, 2].map {|len| place Ship.random(len)}
      self
    end

    def place(ship)
      if can_place? ship
        ship.coordinates.each {|c| cells[c.row][c.col] = ship.length}
      else
        place Ship.random(ship.length)
      end
    end

    def can_place?(ship)
      ship.coordinates.reduce(true) do |m, c|
        m && cells[c.row][c.col] == ''
      end
    end

    def to_s
      cells.to_s
    end
  end

  #
  # Representation of a battleship game piece.
  #
  class Ship
    class << self
      def random(length)
        orientation = Orientation.random
        start = rand_start length, orientation
        self.new(start, length, orientation)
      end

      def rand_start(len, orientation)
        if orientation.vertical?
          Coordinate.new rand(10 - len), rand(10)
        else
          Coordinate.new rand(10), rand(10 - len)
        end
      end
    end

    attr_reader :start, :length, :orientation

    def initialize(start, length, orientation)
      @start, @length, @orientation = start, length, orientation
    end

    def coordinates
      dir = orientation.vertical? ? :down : :right
      (1...length).inject([start]) {|c| c << c.last.send(dir)}
    end
  end


  #
  # Piece orientation
  #
  class Orientation
    ORIENTATIONS = [:horizontal, :vertical]

    def self.random
      Orientation.new ORIENTATIONS[rand(2)]
    end

    def initialize(which)
      @which = which
    end

    def horizontal?
      @which == :horizontal
    end

    def vertical?
      !horizontal?
    end
  end

  #
  # Representations of the board cells.
  #
  class Coordinate
    HEADERS = ('A'..'J').to_a

    attr_reader :row, :col

    def initialize(row ,col)
      @row, @col = row, col
    end

    def up
      Coordinate.new(row.pred, col)
    end

    def down
      Coordinate.new(row.next, col)
    end

    def right
      Coordinate.new(row, col.next)
    end

    def left
      Coordinate.new(row, col.pred)
    end

    def adjacent
      [up, down, right, left].select(&:valid?)
    end

    def valid?
      [row, col].reduce(true) {|m, v| m && v <= 9 && v >= 0}
    end

    def ==(other)
      col == other.col && row == other.row
    end

    def to_s
      "#{HEADERS[col]}#{row+1}"
    end
  end
end

print <<'eos'
  ___        _    _    _        ___
 | _ ) __ _ | |_ | |_ | | ___  / __| _ _  ___  _  _  _ __
 | _ \/ _` ||  _||  _|| |/ -_)| (_ || '_|/ _ \| || || '_ \
 |___/\__,_| \__| \__||_|\___| \___||_|  \___/ \_,_|| .__/
                                                    |_|

eos

BattleGroup.general_quarters