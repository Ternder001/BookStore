
#[starknet::contract]
mod BookStore {
    use starknet::ContractAddress;
    use starknet::{get_caller_address, storage_access::StorageBaseAddress};

    #[storage]
    struct Storage {
        book_count: u128,
        books: LegacyMap::<u128, Book>,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct Book {
        id: u128,
        title: felt252,
        author: felt252,
        price: u128,
        seller: ContractAddress,
        is_sold: bool,
    }

    // Custom Errors
    #[derive(Drop, Debug)]
    pub enum Error {
        BookDoesNotExist,
        BookAlreadySold,
        InsufficientFunds,
        SellerCannotPurchase,
        NotBookSeller,
        InvalidBookData,
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BookAdded: BookAddedEvent,
        BookPurchased: BookPurchasedEvent,
        BookUpdated: BookUpdatedEvent,
    }

    #[derive(Drop, starknet::Event)]
    struct BookAddedEvent {
        book_id: u128,
        title: felt252,
        author: felt252,
        price: u128,
        seller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct BookPurchasedEvent {
        book_id: u128,
        title: felt252,
        author: felt252,
        price: u128,
        buyer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct BookUpdatedEvent {
        book_id: u128,
        title: felt252,
        author: felt252,
        price: u128,
    }

    // Contract Functions
    #[constructor]
    fn constructor(ref self: ContractState) {
        self.book_count.write(0);
    }

    #[external(v0)]
    fn add_book(ref self: ContractState, title: felt252, author: felt252, price: u128) -> Result<(), Error> {
        if title == 0.into() || author == 0.into() || price == 0 {
            Error::InvalidBookData;
        }

        let book_count = self.book_count.read();
        let caller = get_caller_address();

        let new_book = Book {
            id: book_count + 1,
            title: title,
            author: author,
            price: price,
            seller: caller,
            is_sold: false,
        };

        self.books.write(book_count + 1, new_book);
        self.book_count.write(book_count + 1);

        self.emit(BookAddedEvent {
            book_id: book_count + 1,
            title: title,
            author: author,
            price: price,
            seller: caller,
        });

    }

    #[external(v0)]
    fn purchase_book(ref self: ContractState, book_id: u128, amount: u128) -> Result<(), Error> {
        if book_id == 0 || book_id > self.book_count.read() {
            Error::BookDoesNotExist;
        }

        let mut book = self.books.read(book_id).unwrap(); // Should handle Option properly
        let caller = get_caller_address();

        if book.is_sold {
            Error::BookAlreadySold;
        }

        if amount < book.price {
            Error::InsufficientFunds;
        }

        if book.seller == caller {
            Error::SellerCannotPurchase;
        }

        // Mark the book as sold
        book.is_sold = true;
        self.books.write(book_id, book);

        self.emit(BookPurchasedEvent {
            book_id: book.id,
            title: book.title,
            author: book.author,
            price: book.price,
            buyer: caller,
        });

    }

    fn get_book(self: @ContractState, book_id: u128) -> (u128, felt252, felt252, u128, ContractAddress, bool) {
        if book_id == 0 || book_id > self.book_count.read() {
            panic!("Book does not exist");
        }

        let book = self.books.read(book_id).unwrap(); // Handle Option carefully in production

        (book.id, book.title, book.author, book.price, book.seller, book.is_sold)
    }

    #[external(v0)]
    fn update_book(
        ref self: ContractState,
        book_id: u128,
        new_title: felt252,
        new_author: felt252,
        new_price: u128
    ) -> Result<(), Error> {
        if book_id == 0 || book_id > self.book_count.read() {
            Error::BookDoesNotExist;
        }

        let mut book = self.books.read(book_id).unwrap();
        let caller = get_caller_address();

        if book.is_sold {
            Error::BookAlreadySold;
        }

        if book.seller != caller {
            Error::NotBookSeller;
        }

        if new_title == 0.into() || new_author == 0.into() || new_price == 0 {
            Error::InvalidBookData;
        }

        // Update the book details
        book.title = new_title;
        book.author = new_author;
        book.price = new_price;
        self.books.write(book_id, book);

        self.emit(BookUpdatedEvent {
            book_id: book_id,
            title: new_title,
            author: new_author,
            price: new_price,
        });

    }
}
