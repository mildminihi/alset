import Foundation

// MARK: - Tesla Fleet API envelope

/// Standard Tesla API response wrapper: `{ "response": { ... } }`.
struct TeslaAPIResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let response: T
}

// MARK: - Vehicle data (vehicle_data endpoint)

/// Subset of `GET /api/1/vehicles/{vin}/vehicle_data` focused on charge, climate, and vehicle state.
struct TeslaVehicleData: Decodable, Sendable {
    let chargeState: ChargeState?
    let climateState: ClimateState?
    let vehicleState: VehicleState?

    enum CodingKeys: String, CodingKey {
        case chargeState = "charge_state"
        case climateState = "climate_state"
        case vehicleState = "vehicle_state"
    }
}

/// Battery and charging information from `charge_state`.
struct ChargeState: Decodable, Sendable {
    let batteryLevel: Int?
    let usableBatteryLevel: Int?

    enum CodingKeys: String, CodingKey {
        case batteryLevel = "battery_level"
        case usableBatteryLevel = "usable_battery_level"
    }
}

/// Climate control information from `climate_state`.
struct ClimateState: Decodable, Sendable {
    let insideTemp: Double?
    let outsideTemp: Double?
    let isClimateOn: Bool?

    enum CodingKeys: String, CodingKey {
        case insideTemp = "inside_temp"
        case outsideTemp = "outside_temp"
        case isClimateOn = "is_climate_on"
    }
}

/// Physical vehicle state from `vehicle_state` (maps to "car_state" in app terminology).
struct VehicleState: Decodable, Sendable {
    let carVersion: String?
    let locked: Bool?

    enum CodingKeys: String, CodingKey {
        case carVersion = "car_version"
        case locked
    }
}

// MARK: - UI-friendly snapshot

/// Flattened view of the fields most commonly shown in the dashboard.
struct TeslaVehicleSnapshot: Sendable {
    let batteryLevel: Int?
    let usableBatteryLevel: Int?
    let insideTemp: Double?
    let outsideTemp: Double?
    let isClimateOn: Bool?
    let carVersion: String?
    let locked: Bool?

    init(from data: TeslaVehicleData) {
        batteryLevel = data.chargeState?.batteryLevel
        usableBatteryLevel = data.chargeState?.usableBatteryLevel
        insideTemp = data.climateState?.insideTemp
        outsideTemp = data.climateState?.outsideTemp
        isClimateOn = data.climateState?.isClimateOn
        carVersion = data.vehicleState?.carVersion
        locked = data.vehicleState?.locked
    }
}

// MARK: - Supabase auth row

/// Row shape for `public.tesla_auth` in Supabase.
struct TeslaAuthRecord: Codable, Sendable {
    let id: UUID
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var vin: String?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case vin
        case updatedAt = "updated_at"
    }
}

// MARK: - OAuth token refresh response

/// Response from `POST /oauth2/v3/token` when using `grant_type=refresh_token`.
struct TeslaTokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}
