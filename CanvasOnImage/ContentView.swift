//
//  ContentView.swift
//  CanvasOnImage
//
//  Created by Ivan Lvov on 12.05.2023.
//

import SwiftUI

struct ContentView: View {
    @State var isPresented: Bool = false
    @State var image: UIImage?
    
    var body: some View {
        
        VStack{
            Text("Draw")
                .onTapGesture {
                    isPresented = true
                }
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        }
        .sheet(isPresented: $isPresented) {
            CanvasOnImageView(viewModel: CanvasOnImageViewModel(isPresented: $isPresented, image: UIImage(named: "example")!, onFinish: { resultImage in
                self.image = resultImage
                UIImageWriteToSavedPhotosAlbum(resultImage, nil, nil, nil)
            }))
        }
        
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
