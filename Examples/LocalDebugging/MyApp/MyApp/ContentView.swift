//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftAWSLambdaRuntime project authors
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

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            TextField("Username", text: $name)
            SecureField("Password", text: $password)
            Button(
                action: {
                    Task {
                        await self.register()
                    }
                },
                label: {
                    Text("Register")
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.black)
                        .border(Color.black, width: 2)
                }
            )
            Text(response)
        }.padding(100)
    }

    func register() async {
        guard let url = URL(string: "http://127.0.0.1:7000/invoke") else {
            fatalError("invalid url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        guard let jsonRequest = try? JSONEncoder().encode(Request(name: self.name, password: self.password)) else {
            fatalError("encoding error")
        }
        request.httpBody = jsonRequest

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CommunicationError(reason: "invalid response, expected HTTPURLResponse")
            }
            guard httpResponse.statusCode == 200 else {
                throw CommunicationError(reason: "invalid response code: \(httpResponse.statusCode)")
            }
            let jsonResponse = try JSONDecoder().decode(Response.self, from: data)

            self.response = jsonResponse.message
        } catch {
            self.response = error.localizedDescription
        }
    }

    func setResponse(_ text: String) {
        DispatchQueue.main.async {
            self.response = text
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct CommunicationError: Error {
    let reason: String
}
