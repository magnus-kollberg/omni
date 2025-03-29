import Foundation
import Network
import os.log

class NetworkDiscoveryManager: NSObject, ObservableObject {
    @Published var discoveredDevices: [String] = []
    @Published var error: String?
    @Published var isScanning = false
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.omni.networkdiscovery")
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.omni", category: "NetworkDiscoveryManager")
    
    override init() {
        super.init()
    }
    
    func startDiscovery() {
        // Ensure we're not already scanning
        if isScanning {
            stopDiscovery()
        }
        
        // Clear any existing state
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.discoveredDevices.removeAll()
            self.error = nil
            self.isScanning = true
        }
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        // Create a browser for discovering HTTP services
        let browserDescriptor = NWBrowser.Descriptor.bonjour(type: "_http._tcp", domain: "local")
        browser = NWBrowser(for: browserDescriptor, using: parameters)
        
        browser?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            
            switch state {
            case .ready:
                self.logger.info("Browser is ready")
            case .failed(let error):
                self.logger.error("Browser failed with error: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.error = "Failed to start network discovery: \(error.localizedDescription)"
                    self.isScanning = false
                }
            case .cancelled:
                self.logger.info("Browser was cancelled")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isScanning = false
                }
            case .setup:
                self.logger.info("Browser is setting up")
            @unknown default:
                self.logger.info("Browser state changed to unknown state")
            }
        }
        
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self = self else { return }
            
            self.logger.info("Found \(results.count) services")
            for result in results {
                if case .service(let name, let type, let domain, _) = result.endpoint {
                    self.logger.info("Found service: \(name) of type \(type) in domain \(domain)")
                    if name.hasPrefix("kollberg-") && !self.discoveredDevices.contains(name) {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            self.discoveredDevices.append(name)
                        }
                    }
                }
            }
        }
        
        browser?.start(queue: queue)
    }
    
    func stopDiscovery() {
        // Cancel browser immediately
        browser?.cancel()
        browser = nil
        
        // Update UI state on main queue
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isScanning = false
            self.discoveredDevices.removeAll()
            self.error = nil
        }
    }
    
    deinit {
        // Perform cleanup synchronously to avoid weak reference issues
        browser?.cancel()
        browser = nil
    }
} 