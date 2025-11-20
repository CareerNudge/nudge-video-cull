//
//  StarRatingView.swift
//  VideoCullingApp
//

import SwiftUI

struct StarRatingView: View {
    // Use Int16 to match the Core Data model
    @Binding var rating: Int16

    var label = "Rating"
    var maximumRating = 5
    var offImage = Image(systemName: "star")
    var onImage = Image(systemName: "star.fill")
    var offColor = Color.gray
    var onColor = Color.yellow
    var showLabel = true
    var isDisabled = false

    var body: some View {
        HStack {
            if showLabel {
                Text(label + ":")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Spacer()
            }

            ForEach(1...maximumRating, id: \.self) { number in
                image(for: number)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(isDisabled ? Color.gray.opacity(0.3) : (number > rating ? offColor : onColor))
                    .frame(width: 20, height: 20)
                    .onTapGesture {
                        if !isDisabled {
                            // Allow tapping the same star to reset to 0
                            if number == rating {
                                rating = 0
                            } else {
                                rating = Int16(number)
                            }
                        }
                    }
            }
        }
        .frame(maxWidth: showLabel ? 200 : .infinity)
    }

    func image(for number: Int) -> Image {
        if number > rating {
            return offImage
        } else {
            return onImage
        }
    }
}
