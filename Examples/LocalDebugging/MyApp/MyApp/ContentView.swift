//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2020-2021 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Shared
import SwiftUI

struct ContentView: View {
    @State var name: String = ""
    @State var password: String = ""
    @State var response: String = ""
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            TextField("Username", text: $name)
            SecureField("Password", text: $password)
            let inputIncomplete = name.isEmpty || password.isEmpty
            Button {
                Task {
                    isLoading = true
                    do {
                        response = try await self.register()
                    } catch {
                        response = error.localizedDescription
                    }
                    isLoading = false
                }
            } label: {
                Text("Register")
                    .padding()
                    .foregroundColor(.white)
                    .background(.black)
                    .border(.black, width: 2)
                    .opacity(isLoading ? 0 : 1)
                    .overlay {
                        if isLoading {
                            ProgressView()
                        }
                    }
            }
            .disabled(inputIncomplete || isLoading)
            .opacity(inputIncomplete ? 0.5 : 1)
            Text(response)
        }.padding(100)
    }

    func register() async throws -> String {
        guard let url = URL(string: "http://127.0.0.1:7000/invoke") else {
            fatalError("invalid url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        guard let jsonRequest = try? JSONEncoder().encode(Request(name: self.name, password: self.password)) else {
            fatalError("encoding error")
        }
        request.httpBody = jsonRequest

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CommunicationError(reason: "Invalid response, expected HTTPURLResponse.")
        }
        guard httpResponse.statusCode == 200 else {
            throw CommunicationError(reason: "Invalid response code: \(httpResponse.statusCode)")
        }

        let jsonResponse = try JSONDecoder().decode(Response.self, from: data)
        return jsonResponse.message
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct CommunicationError: LocalizedError {
    let reason: String
    var errorDescription: String? {
        self.reason
    }
}
