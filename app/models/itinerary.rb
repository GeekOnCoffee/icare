class Itinerary
  include Mongoid::Document
  include Mongoid::Paranoia
  include Mongoid::Geospatial
  include Mongoid::MultiParameterAttributes

  VEHICLE = %w(car motorcycle van)
  DAYNAME = %w(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)

  attr_accessible :title, :description, :vehicle, :num_people, :smoking_allowed, :pets_allowed, :fuel_cost, :tolls
  attr_accessible :round_trip, :leave_date, :return_date
  attr_accessible :share_on_timeline

  belongs_to :user
  delegate :name, to: :user, prefix: true
  delegate :first_name, to: :user, prefix: true

  has_many :conversations, as: :conversable

  # Route
  field :start_location, type: Point, spatial: true
  field :end_location, type: Point, spatial: true
  field :via_waypoints, type: Array
  field :overview_path, type: Array
  field :overview_polyline, type: String

  # Details
  field :title
  field :description
  field :vehicle, default: "car"
  field :num_people, type: Integer
  field :smoking_allowed, type: Boolean, default: false
  field :pets_allowed, type: Boolean, default: false
  field :fuel_cost, type: Integer
  field :tolls, type: Integer
  field :round_trip, type: Boolean, default: false
  field :leave_date, type: DateTime, default: -> { (Time.now).change(min: (Time.now.min / 10) * 10) + 10.minutes }
  field :return_date, type: DateTime, default: -> { (Time.now).change(min: (Time.now.min / 10) * 10) + 70.minutes }
  field :recurrent, type: Boolean, default: false

  # Cached user details (for filtering purposes)
  field :driver_gender

  attr_accessor :route_json_object, :share_on_timeline

  spatial_index :start_location
  spatial_index :end_location

  #default_scope -> { any_of({:leave_date.gte => Time.now.utc}, {:return_date.gte => Time.now.utc, round_trip: true}, { recurrent: true }) }

  validates :title, length: { maximum: 40 }, presence: true
  validates :description, length: { maximum: 1000 }, presence: true
  validates :vehicle, inclusion: VEHICLE
  validates :num_people, numericality: { only_integer: true, greater_than: 0, less_than: 10 }, allow_blank: true
  validates :fuel_cost, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 10000 }
  validates :tolls, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 10000 }

  validates :leave_date, timeliness: { on_or_after: -> { Time.now } }, on: :create
  validate :return_date_validator, if: -> { round_trip }

  def return_date_validator
    self.errors.add(:return_date, I18n.t("mongoid.errors.messages.after", restriction: leave_date.strftime(I18n.t("validates_timeliness.error_value_formats.datetime")))) if return_date <= leave_date
  end

  def self.build_with_route_json_object(params, user)
    new(params) do |itinerary|
      route_json_object = JSON.parse(params[:route_json_object])
      itinerary.start_location = { lat: route_json_object["start_location"]["lat"],
                                   lng: route_json_object["start_location"]["lng"] }
      itinerary.end_location = { lat: route_json_object["end_location"]["lat"],
                                 lng: route_json_object["end_location"]["lng"] }
      itinerary.via_waypoints = route_json_object["via_waypoints"]
      itinerary.overview_path = route_json_object["overview_path"]
      itinerary.overview_polyline = route_json_object["overview_polyline"]

      itinerary.user = user

      itinerary.driver_gender = user.gender
    end
  end

  def self.search(params)
    # TODO: Optimization
    itineraries = Itinerary.where(get_boolean_filters(params))

    itineraries_start = itineraries.includes(:user).where(:start_location.near(:sphere) => { point: [params[:start_location_lat], params[:start_location_lng]],
                                                                                             max: 5,
                                                                                             unit: :km })
    itineraries_end = Itinerary.where(:end_location.near(:sphere) => { point: [params[:end_location_lat], params[:end_location_lng]],
                                                                       max: 5,
                                                                       unit: :km })

    itineraries_start & itineraries_end
  rescue
  end

  def to_latlng_array(field)
    return unless [:start_location, :end_location].include?(field)
    [ self[field]["lat"], self[field]["lng"] ]
  end

  def sample_path(precision = 10)
    overview_path.in_groups(precision).map{ |g| g.first }.insert(-1,overview_path.last)
  end

  def static_map
    URI.encode("http://maps.googleapis.com/maps/api/staticmap?size=200x200&sensor=false&markers=color:green|label:B|#{to_latlng_array(:end_location).join(",")}&markers=color:green|label:A|#{to_latlng_array(:start_location).join(",")}&path=enc:#{overview_polyline}")
  end

  def start_location
    # GOD(DAMN) mongoid_geospatial
    @start_location ||= self[:start_location]
  end

  def end_location
    # GOD(DAMN) mongoid_geospatial
    @end_location ||= self[:end_location]
  end

  def random_close_location(max_dist = 0.5, km = true)
    # Thanks to http://www.geomidpoint.com/random/calculation.html

    return unless source && source[:lat] != nil && source[:lng] != nil

    deg_to_rad = Math::PI / 180
    rad_to_deg = 180 / Math::PI
    radius_earth_M = 3960.056052
    radius_earth_Km = 6372.796924

    rand1 = rand
    rand2 = rand

    # Convert all latitudes and longitudes to radians
    start_lat = source[:lat] * deg_to_rad
    start_lng = source[:lng] * deg_to_rad

    # Convert maximum distance to radians.
    max_dist_rad = max_dist / (km ? radius_earth_Km : radius_earth_M)

    # Compute a random distance from 0 to maxdist scaled
    # so that points on larger circles have a greater probability
    # of being chosen than points on smaller circles as described earlier.
    dist = Math::acos( rand1 * (Math::cos(max_dist_rad) - 1) + 1 )

    # Compute a random bearing from 0 to 2*PI radians (0 to 360 degrees),
    # with all bearings having an equal probability of being chosen.
    brg = 2 * Math::PI * rand2

    # Use the starting point, random distance and random bearing to calculate the coordinates of the final random point.
    lat = Math::asin( Math::sin(start_lat) * Math::cos(dist) + Math::cos(start_lat) * Math::sin(dist) * Math::cos(brg) )
    lng = start_lng + Math::atan2( Math::sin(brg) * Math::sin(dist) * Math::cos(start_lat), Math::cos(dist) - Math::sin(start_lat) * Math.sin(lat) )

    if (lng < -1 * Math::PI)
      lng = lng + 2 * Math::PI
    elsif (lng > Math::PI)
      lng = lng - 2 * Math::PI
    end

    [lat * rad_to_deg, lng * rad_to_deg]
  end

  def to_s
    title || super()
  end

private
  def self.get_boolean_filters(params = {})
    filters = {}
    [:smoking_allowed, :pets_allowed, :round_trip].each do |boolean_field|
      param = params["filter_#{boolean_field}".to_sym]
      filters.merge!(boolean_field => (param == "true")) unless param.blank?
    end
    filter_driver_gender_param = params[:filter_driver_gender]
    filters.merge!(driver_gender: filter_driver_gender_param) if User::GENDER.include?(filter_driver_gender_param)
    filters
  end
end
