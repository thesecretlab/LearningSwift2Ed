// this file is a modification of the Swift Package Manager example project written by Apple as part of the Swift.org open source project
// Copyright Apple and the Swift project authors, licensed under the Apache License v2.0 with Runtime Library Exception
// https://github.com/apple/example-package-dealer

// BEGIN package_manager_main
import DeckOfPlayingCards

var deck = Deck.standard52CardDeck()
deck.shuffle()

for _ in 0...5
{
	guard let card = deck.deal() else
	{
		print("No More Cards!")
		break
	}
	print(card)
}
// END package_manager_main
