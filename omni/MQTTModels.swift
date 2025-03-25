struct MQTTSettings: Codable {
    var server: String
    var port: Int
    var user: String
    
    var formattedString: String {
        """
        Server: \(server)
        Port: \(port)
        User: \(user)
        """
    }
} 