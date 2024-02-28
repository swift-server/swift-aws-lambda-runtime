import Foundation

public struct MDBShow: Codable, Identifiable {
    public private(set) var id: Int
    public private(set) var title: String
    public private(set) var tagline: String
    public private(set) var originalTitle: String
    public private(set) var originalLanguage: String
    public private(set) var originCountries: [String]
    public private(set) var overview: String
    public private(set) var isInProduction: Bool
    public private(set) var currentStatus: String
    public private(set) var homepage: String?
    
    public private(set) var genres: [MDBGenre]
    
    public private(set) var backdropPath: String?
    public private(set) var posterPath: String?
    
    public private(set) var voteAverage: Double
    public private(set) var voteCount: Int
    public private(set) var popularity: Double
    
    public private(set) var episodesRuntime: [Int]
    
    public private(set) var firstAirDate: Date
    public private(set) var lastAirDate: Date
    
    public private(set) var networks: [MDBShow.Network]
    public private(set) var productionCompanies: [MDBShow.ProductionCompany]
    
    public private(set) var seasonCount: Int
    public private(set) var episodeCount: Int
    
    public private(set) var seasons: [MDBShow.Season]
    
    private enum CodingKeys: String, CodingKey {
        case id
        case title = "name"
        case tagline
        case originalTitle = "original_name"
        case originalLanguage = "original_language"
        case originCountries = "origin_country"
        case overview
        case isInProduction = "in_production"
        case currentStatus = "status"
        case homepage
        case genres
        case backdropPath = "backdrop_path"
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case popularity = "popularity"
        case episodesRuntime = "episode_run_time"
        case firstAirDate = "first_air_date"
        case lastAirDate = "last_air_date"
        case networks
        case productionCompanies = "production_companies"
        case seasonCount = "number_of_seasons"
        case episodeCount = "number_of_episodes"
        case seasons
    }
}

public extension MDBShow {
    typealias ProductionCompany = Network
    
    struct Season: Codable, Identifiable {
        public private(set) var id: Int
        public private(set) var name: String
        public private(set) var overview: String
        public private(set) var posterPath: String?
        public private(set) var seasonNumber: Int
        public private(set) var episodeCount: Int
        public private(set) var airDate: String?
        
        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case overview
            case posterPath = "poster_path"
            case seasonNumber = "season_number"
            case episodeCount = "episode_count"
            case airDate = "air_date"
        }
    }
    
    struct Network: Codable, Identifiable {
        public private(set) var id: Int
        public private(set) var name: String
        public private(set) var logoPath: String?
        public private(set) var country: String
        
        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case logoPath = "logo_path"
            case country = "origin_country"
        }
    }
    
    struct SpokenLanguage: Codable, Identifiable {
        public private(set) var englishName: String
        public private(set) var name: String
        public private(set) var iso6391: String
        
        public var id: String {
            return self.iso6391
        }
        
        private enum CodingKeys: String, CodingKey  {
            case englishName = "english_name"
            case name
            case iso6391 = "iso_639_1"
        }
    }
}


