//
//  ViewController.swift
//  NIOServer
//
//  Created by danxiao on 2024/7/3.
//

import UIKit
import SwiftUI

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let swiftUIView = ContentView()
        
        // Use a UIHostingController to wrap the SwiftUI view.
        let hostingController = UIHostingController(rootView: swiftUIView)
        
        // Add as a child of the current view controller.
        self.addChild(hostingController)
        
        // Add the SwiftUI view to the view controller view hierarchy.
        self.view.addSubview(hostingController.view)
        
        // Set up constraints to make the hosting view fill the entire screen.
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        // Notify the hosting controller that it has been moved to the current view controller.
        hostingController.didMove(toParent: self)
    }


}

