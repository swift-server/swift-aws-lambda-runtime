//
//  LambdaRuntime+ServiceLifecycle.swift
//  swift-aws-lambda-runtime
//
//  Created by Fabian Fett on 01.03.25.
//

#if ServiceLifecycleSupport
import ServiceLifecycle

extension LambdaRuntime: Service {}
#endif
