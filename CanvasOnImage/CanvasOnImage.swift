//
//  CanvasOnImage.swift
//  CanvasOnImage
//
//  Created by Ivan Lvov on 12.05.2023.
//

import Foundation
import SwiftUI

// This code declares a Line struct that contains an array of points and a color, used for drawing lines on an image.
struct Line {
    var points: [CGPoint]
    var color: Color
}

// CanvasOnImageView is a View that allows user to draw on an image using gestures. It uses CanvasOnImageViewModel as its ViewModel.
struct CanvasOnImageView: View {
    @ObservedObject var viewModel: CanvasOnImageViewModel
    
    var body: some View {
        NavigationView {
            ZStack{
                // Display the image from the view model
                Image(uiImage: viewModel.image)
                    .offset(viewModel.currentOffset)
                
                // Draw each line in the lines array. The coordinates of the line points are adjusted based on the current offset of the image.
                Canvas { ctx, size in
                    for line in viewModel.lines {
                        var path = Path()
                        for point in line.points {
                            let adjustedPoint = CGPoint(x: point.x - viewModel.currentOffset.width, y: point.y - viewModel.currentOffset.height)
                            path.addLine(to: adjustedPoint)
                        }
                        // stroke the path with the color of the line and style
                        ctx.stroke(path, with: .color(line.color), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                }
                // Enable dragging on the canvas, triggering the corresponding methods in the view model on changes or when the drag ends.
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged(viewModel.handleDrag)
                        .onEnded(viewModel.handleDragEnd)
                )
            }
            .scaleEffect(viewModel.scaleEffect) // Scale the whole stack based on the scale effect from the view model
            .overlay(
                // Overlay the controls view on top of the stack
                CanvasOnImageControlsView(viewModel: viewModel)
                    .offset(y: 300)
            )
            // Add a toolbar with Save and Cancel buttons
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: {
                        viewModel.finish()
                    })
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: {
                        viewModel.dismiss()
                    })
                }
                
            }
            
        }
        // When the view appears, calculate the initial scale for the image
        .onAppear{
            viewModel.calculateInitialScale()
        }
    }
}

// CanvasOnImageControlsView is a View that displays controls for the CanvasOnImageView, such as color selection, clearing, panning, and zooming.
struct CanvasOnImageControlsView: View {
    @ObservedObject var viewModel: CanvasOnImageViewModel
    
    var body: some View {
        HStack(spacing: 16){
            ForEach([Color.black, .white], id: \.self) { color in
                viewModel.colorButton(color: color)
            }
            viewModel.clearButton()
            viewModel.panButton()
            viewModel.zoomInButton()
            viewModel.zoomOutButton()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.2)))
        
    }
}


class CanvasOnImageViewModel: ObservableObject {
    @Binding var isPresented: Bool
    
    private var initialImage: UIImage
    var onFinish: (_ image: UIImage) -> Void
    
    @Published var lines: [Line] = []
    @Published var selectedColor = Color.black
    
    @Published var image: UIImage // The image to be edited.
    @Published var scaleEffect: CGFloat = 0.5 // The scale of the image.
    
    @Published var currentOffset: CGSize = .zero // The offset of the image.
    @Published var isPanning: Bool = false // Flag indicating whether the image is being panned.
    private var lastOffset: CGSize = .zero // The last offset of the image before panning.
    
    // The initializer takes a binding to a boolean (indicating whether the view is presented), an image, and a callback to execute when editing is finished.
    init(isPresented: Binding<Bool>, image: UIImage, onFinish: @escaping (UIImage) -> Void) {
        _isPresented = isPresented
        self.initialImage = image
        self.image = image
        self.onFinish = onFinish
    }
    
    // Calculates the initial scale of the image based on the screen size and the image size. We need this because we don't resize the image.
    func calculateInitialScale() {
        let screenSize = UIScreen.main.bounds.size
        let scale = min(screenSize.width / initialImage.size.width, screenSize.height / initialImage.size.height)
        scaleEffect = scale
    }
    
    // Saves the drawn lines onto the image.
    func save() {
        // Create a new image context
        UIGraphicsBeginImageContext(image.size)
        
        // Draw the base image
        image.draw(at: .zero)
        
        // Convert lines to UIBezierPaths and draw them onto the context
        for line in lines {
            let bezierPath = UIBezierPath()
            bezierPath.lineWidth = 5
            UIColor(line.color).setStroke()
            
            for (i, point) in line.points.enumerated() {
                if i == 0 {
                    bezierPath.move(to: point)
                } else {
                    bezierPath.addLine(to: point)
                }
            }
            
            bezierPath.stroke()
        }
        
        // Get the combined image
        let combinedImage = UIGraphicsGetImageFromCurrentImageContext()
        
        // End the image context
        UIGraphicsEndImageContext()
        
        lines = []
        
        guard let finalImage = combinedImage else { return }
        image = finalImage
    }
    
    // Finishes editing, calls the onFinish callback, and dismisses the view.
    func finish() {
        onFinish(image)
        dismiss()
    }
    
    // Dismisses the view.
    func dismiss(){
        self.isPresented = false
    }
    
    // Handles dragging on the canvas. If the image is being panned, the offset is updated. Otherwise, a new line is started or an existing line is continued.
    func handleDrag(value: DragGesture.Value) {
        if isPanning {
            self.currentOffset = CGSize(width: value.translation.width + self.lastOffset.width, height: value.translation.height + self.lastOffset.height)
            return
        }
        
        let position = value.location
        if !self.isPanning {
            if value.translation == .zero {
                lines.append(Line(points: [CGPoint(x: position.x - self.currentOffset.width, y: position.y - self.currentOffset.height)], color: selectedColor))
            } else {
                guard let lastIdx = lines.indices.last else {
                    return
                }
                
                lines[lastIdx].points.append(CGPoint(x: position.x - self.currentOffset.width, y: position.y - self.currentOffset.height))
            }
        }
    }
    
    
    // Handles the end of a drag event. If the image was being panned, the last offset is updated. Otherwise, the lines are saved onto the image.
    func handleDragEnd(_ value: DragGesture.Value) {
        if isPanning {
            self.lastOffset = self.currentOffset
        } else {
            save()
        }
    }
    
    // Returns a View representing a button for selecting a color. When the button is tapped, the selected color in the view model is updated and panning is disabled.
    func colorButton(color: Color) -> some View {
        Button {
            self.selectedColor = color
            self.isPanning = false
        } label: {
            Image(systemName: "circle.fill")
                .font(.largeTitle)
                .foregroundColor(color)
                .mask {
                    Image(systemName: "pencil.tip")
                        .font(.largeTitle)
                }
        }
    }
    
    // Returns a View representing a button for clearing the image. When the button is tapped, the lines array is cleared, the image is reset to the initial image, the initial scale is recalculated, and the current offset is reset.
    func clearButton() -> some View {
        Button {
            self.lines = []
            self.image = self.initialImage
            self.calculateInitialScale()
            self.currentOffset = .zero
        } label: {
            Image(systemName: "pencil.tip.crop.circle.badge.minus")
                .font(.largeTitle)
                .foregroundColor(.gray)
        }
    }
    
    // Returns a View representing a button for toggling panning mode. When the button is tapped, the isPanning flag in the view model is toggled.
    func panButton() -> some View {
        Button(action: {
            self.isPanning.toggle()
        }) {
            Image(systemName: self.isPanning ? "hand.draw" : "hand.raised")
                .font(.largeTitle)
                .foregroundColor(.gray)
        }
    }
    
    // Returns a View representing a button for zooming in on the image. When the button is tapped, panning is disabled and the scale effect is increased.
    func zoomInButton() -> some View {
        Button(action: {
            self.isPanning = false
            self.scaleEffect += 0.1
        }) {
            Image(systemName: "plus.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.gray)
        }
    }
    
    // Returns a View representing a button for zooming out of the image. When the button is tapped, panning is disabled and the scale effect is decreased.
    func zoomOutButton() -> some View {
        Button(action: {
            self.isPanning = false
            self.scaleEffect -= 0.1
        }) {
            Image(systemName: "minus.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.gray)
        }
    }
    
}
