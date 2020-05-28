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
                action: self.register,
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

    func register() {
        guard let url = URL(string: "http://localhost:7000/invoke") else {
            fatalError("invalid url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        guard let jsonRequest = try? JSONEncoder().encode(Request(name: self.name, password: self.password)) else {
            fatalError("encoding error")
        }
        request.httpBody = jsonRequest

        let task = URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            do {
                if let error = error {
                    throw CommunicationError(reason: error.localizedDescription)
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw CommunicationError(reason: "invalid response, expected HTTPURLResponse")
                }
                guard httpResponse.statusCode == 200 else {
                    throw CommunicationError(reason: "invalid response code: \(httpResponse.statusCode)")
                }
                guard let data = data else {
                    throw CommunicationError(reason: "invald response, empty body")
                }
                let response = try JSONDecoder().decode(Response.self, from: data)
                self.setResponse(response.message)
            } catch {
                self.setResponse("\(error)")
            }
        }
        task.resume()
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
