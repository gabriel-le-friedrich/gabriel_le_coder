// const State = {
//     data: {
//         user: null,
//         currentTranslation: "06125adad2d5898a-01",
//         currentBook: "GEN",
//         currentChapter: 1,
//         bookmarks: [],
//         highlights: [],
//         notes: []
//     },
    
//     get(key) {
//         return this.data[key];
//     },
    
//     set(key, value) {
//         this.data[key] = value;
//         this.notifyListeners(key);
//         return value;
//     },
    
//     // Observer pattern for UI updates
//     listeners: {},
    
//     subscribe(key, callback) {
//         if (!this.listeners[key]) {
//             this.listeners[key] = [];
//         }
//         this.listeners[key].push(callback);
//     },
    
//     notifyListeners(key) {
//         if (this.listeners[key]) {
//             this.listeners[key].forEach(callback => callback(this.data[key]));
//         }
//     },
    
//     // Load initial state
//     loadFromStorage() {
//         const savedUser = localStorage.getItem("bibleAppUser");
//         if (savedUser) {
//             try {
//                 this.set('user', JSON.parse(savedUser));
//                 this.loadUserData();
//             } catch (e) {
//                 console.error("Error parsing saved user:", e);
//                 localStorage.removeItem("bibleAppUser");
//             }
//         }
//     },
    
//     loadUserData() {
//         if (!this.data.user || !this.data.user.email) return;
        
//         const userData = localStorage.getItem(`bibleAppData_${this.data.user.email}`);
//         if (userData) {
//             try {
//                 const data = JSON.parse(userData);
//                 this.set('bookmarks', data.bookmarks || []);
//                 this.set('highlights', data.highlights || []);
//                 this.set('notes', data.notes || []);
//             } catch (e) {
//                 console.error("Error loading user data:", e);
//             }
//         }
//     },
    
//     saveUserData() {
//         if (!this.data.user || !this.data.user.email) return;
        
//         const userData = {
//             bookmarks: this.data.bookmarks,
//             highlights: this.data.highlights,
//             notes: this.data.notes
//         };
        
//         localStorage.setItem(`bibleAppData_${this.data.user.email}`, JSON.stringify(userData));
//     }
// };

// Default export for the State object
const State = {
    data: {
        user: null,
        currentTranslation: "06125adad2d5898a-01",
        currentBook: "GEN",
        currentChapter: 1,
        bookmarks: [],
        highlights: [],
        notes: []
    },
    
    get(key) {
        return this.data[key];
    },
    
    set(key, value) {
        this.data[key] = value;
        return value;
    },
    
    // Initialize from localStorage
    loadSavedState() {
        const savedUser = localStorage.getItem("bibleAppUser");
        if (savedUser) {
            try {
                this.data.user = JSON.parse(savedUser);
                this.loadUserData();
            } catch (e) {
                console.error("Error parsing saved user:", e);
                localStorage.removeItem("bibleAppUser");
            }
        }
    },
    
    loadUserData() {
        if (!this.data.user || !this.data.user.email) return;
        
        const userData = localStorage.getItem(`bibleAppData_${this.data.user.email}`);
        if (userData) {
            try {
                const data = JSON.parse(userData);
                this.data.bookmarks = data.bookmarks || [];
                this.data.highlights = data.highlights || [];
                this.data.notes = data.notes || [];
            } catch (e) {
                console.error("Error loading user data:", e);
            }
        }
    }
};

export default State;

// Also export an initialization function
export function initializeState() {
    State.loadSavedState();
    return State;
}