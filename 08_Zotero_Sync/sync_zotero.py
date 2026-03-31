import os
import sys

# Try importing pyzotero to ensure the user has the dependency
try:
    from pyzotero import zotero
except ImportError:
    print("Error: The 'pyzotero' library is not installed.")
    print("Please install it by running: pip install pyzotero")
    sys.exit(1)

def main():
    # User Configuration
    # Remember: Your User ID was specified in the request as 7714813.
    # To run this script, you must provide your Zotero API key as an environment variable
    # or replace `ZOTERO_API_KEY_HERE` with your actual key (please do not commit API keys).
    
    ZOTERO_ID = '7714813'
    ZOTERO_TYPE = 'user' # Can be 'group' or 'user'
    ZOTERO_API_KEY = os.environ.get('ZOTERO_API_KEY', 'ZOTERO_API_KEY_HERE')
    
    if ZOTERO_API_KEY == 'ZOTERO_API_KEY_HERE':
        print("Warning: ZOTERO_API_KEY not set. Please set the environment variable or edit the script to include the key.")
        sys.exit(1)
        
    print(f"Connecting to Zotero API for User ID {ZOTERO_ID}...")
    zot = zotero.Zotero(ZOTERO_ID, ZOTERO_TYPE, ZOTERO_API_KEY)
    
    print("Fetching library items...")
    # Fetch top-level items formatted as Bibtex
    items = zot.top(format='bibtex')
    
    output_filename = 'master_library.bib'
    output_path = os.path.join(os.path.dirname(__file__), output_filename)
    
    print(f"Writing library entries to {output_path}...")
    with open(output_path, 'w', encoding='utf-8') as f:
        # If pyzotero top() with format='bibtex' returns entries:
        if isinstance(items, list):
            for item in items:
                f.write(str(item))
                f.write("\n\n")
        elif isinstance(items, str):
            f.write(items)
            
    print("Zotero synchronization complete. Library successfully exported.")

if __name__ == "__main__":
    main()
