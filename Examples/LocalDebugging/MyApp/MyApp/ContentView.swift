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

import Combine
import Shared
import SwiftUI

struct ContentView: View {
    class API: ObservableObject {
        let url = URL(string: "http://localhost:7000/invoke")!

        @Published var message: String = ""

        private var task: AnyCancellable?

        func register(name: String, password: String) {
            self.task?.cancel()

            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            guard let jsonRequest = try? JSONEncoder().encode(Request(name: name, password: password)) else {
                fatalError("encoding error")
            }
            request.httpBody = jsonRequest

            self.task = URLSession.shared.dataTaskPublisher(for: request)
                .map(\.data)
                .decode(type: Response.self, decoder: JSONDecoder())
                .map(\.message)
                .catch { Just("Error: \($0.localizedDescription)") }
                .receive(on: DispatchQueue.main)
                .assign(to: \.message, on: self)
        }
    }

    @State var name: String = ""
    @State var password: String = ""
    @ObservedObject var api = API()

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 20) {
                TextField("Username", text: $name)
                SecureField("Password", text: $password)
            }.padding(.horizontal, 50)
            Button(
                action: { self.api.register(name: self.name, password: self.password) },
                label: {
                    Text("Register")
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.black)
                        .border(Color.black, width: 2)
                }
            )
            Text(api.message)
            Spacer()
        }.padding(.top, 100).padding(.horizontal, 20)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
