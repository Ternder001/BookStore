
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

    // Custom Error Codes (use felt252 for error codes)
    const BOOK_DOES_NOT_EXIST: felt252 = 1;
    const BOOK_ALREADY_SOLD: felt252 = 2;
    const INSUFFICIENT_FUNDS: felt252 = 3;
    const SELLER_CANNOT_PURCHASE: felt252 = 4;
    const NOT_BOOK_SELLER: felt252 = 5;
    const INVALID_BOOK_DATA: felt252 = 6;

    // // Custom Errors
    // #[derive(Drop, Debug)]
    // pub enum Error {
    //     BookDoesNotExist,
    //     BookAlreadySold,
    //     InsufficientFunds,
    //     SellerCannotPurchase,
    //     NotBookSeller,
    //     InvalidBookData,
    // }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BookAdded: BookAdded,
        BookPurchased: BookPurchased,
        BookUpdated: BookUpdated,
    }
   
    #[derive(Drop, starknet::Event)]
    struct BookAdded {
        #[key]
        book_id: u128,
        title: felt252,
        author: felt252,
        price: u128,
        seller: ContractAddress,
    }
    #[derive(Drop, starknet::Event)]
    struct BookPurchased {
        #[key]
        book_id: u128,
        title: felt252,
        author: felt252,
        price: u128,
        buyer: ContractAddress,
    }
    #[derive(Drop, starknet::Event)]
    struct BookUpdated {
        #[key]
        book_id: u128,
        title: felt252,
        author: felt252,
        price: u128,
    }

    // Events
    // #[event]
    // #[derive(Drop, starknet::Event)]
    // enum Event {
    //     BookAdded: BookAddedEvent,
    //     BookPurchased: BookPurchasedEvent,
    //     BookUpdated: BookUpdatedEvent,
    // }

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
    fn add_book(ref self: ContractState, title: felt252, author: felt252, price: u128) {
        if title == 0.into() || author == 0.into() || price == 0 {
            INVALID_BOOK_DATA;
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

        self.emit(BookAdded {
            book_id: book_count + 1,
            title: title,
            author: author,
            price: price,
            seller: caller,
        });
    }

    // Function to purchase a book
    #[external(v0)]
    fn purchase_book(ref self: ContractState, book_id: u128, amount: u128) {
        if book_id == 0 || book_id > self.book_count.read() {
            BOOK_DOES_NOT_EXIST;
        }

        let mut book = self.books.read(book_id);
        let caller = get_caller_address();

        if book.is_sold {
            BOOK_ALREADY_SOLD;
        }

        if amount < book.price {
            INSUFFICIENT_FUNDS;
        }

        if book.seller == caller {
            SELLER_CANNOT_PURCHASE;
        }

        // Mark the book as sold
        book.is_sold;
        self.books.write(book_id, book);

        self.emit(BookPurchased {
            book_id: book.id,
            title: book.title,
            author: book.author,
            price: book.price,
            buyer: caller,
        });
    }


    // Function to get a book's details (view function)
    fn get_book(self: @ContractState, book_id: u128) -> (u128, felt252, felt252, u128, ContractAddress, bool) {
        if book_id == 0 || book_id > self.book_count.read() {
            panic!("Book does not exist");
        }

        let book = self.books.read(book_id);

        (book.id, book.title, book.author, book.price, book.seller, book.is_sold)
    }

    // Function to update a book before it is sold
    #[external(v0)]
    fn update_book(
        ref self: ContractState,
        book_id: u128,
        new_title: felt252,
        new_author: felt252,
        new_price: u128
    ) {
        if book_id == 0 || book_id > self.book_count.read() {
            BOOK_DOES_NOT_EXIST;
        }

        let mut book = self.books.read(book_id);
        let caller = get_caller_address();

        if book.is_sold {
            BOOK_ALREADY_SOLD;
        }

        if book.seller != caller {
            NOT_BOOK_SELLER;
        }

        if new_title == 0.into() || new_author == 0.into() || new_price == 0 {
            INVALID_BOOK_DATA;
        }

        // Update the book details
        book.title = new_title;
        book.author = new_author;
        book.price = new_price;
        self.books.write(book_id, book);

        self.emit(BookUpdated {
            book_id: book_id,
            title: new_title,
            author: new_author,
            price: new_price,
        });
    }
}