import SwiftUI
import Combine

struct Employee: Identifiable, Equatable, Decodable {
    let id: String
    let name: String
    let photoUrl: String?
    let role: Role

    enum Role: String, Decodable { case admin, worker }

    enum CodingKeys: String, CodingKey {
        case id, name, role
        case photoUrl = "photo_url"
    }
}

private struct WorkersResponse: Decodable { let workers: [Employee] }
private struct AuthResponse: Decodable { let ok: Bool; let name: String; let role: String }

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var employees: [Employee] = []
    @Published var currentEmployee: Employee? = nil
    @Published var loadingEmployees = false

    var apiPassword: String { UserDefaults.standard.string(forKey: "worker_password") ?? "" }
    var isConfigured: Bool { !apiPassword.isEmpty }

    private init() {}

    func loadEmployees() async {
        loadingEmployees = true
        defer { loadingEmployees = false }
        guard let url = URL(string: "\(APIClient.base)/api/workers") else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        if let res = try? JSONDecoder().decode(WorkersResponse.self, from: data) {
            employees = res.workers
        }
    }

    func login(employee: Employee, pin: String) async -> Bool {
        guard let url = URL(string: "\(APIClient.base)/api/workers/auth") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let body = try? JSONSerialization.data(withJSONObject: ["id": employee.id, "pin": pin]) else { return false }
        req.httpBody = body
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let auth = try? JSONDecoder().decode(AuthResponse.self, from: data) else { return false }
        currentEmployee = Employee(id: employee.id, name: auth.name, photoUrl: employee.photoUrl,
                                   role: Employee.Role(rawValue: auth.role) ?? .worker)
        return true
    }

    func logout() { currentEmployee = nil }

    func saveAPIPassword(_ pwd: String) {
        UserDefaults.standard.set(pwd, forKey: "worker_password")
    }
}
