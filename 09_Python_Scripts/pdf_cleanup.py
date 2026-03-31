import os
import re
import shutil
import sys
from pathlib import Path

try:
    import fitz  # PyMuPDF
except ImportError:
    print("Warning: PyMuPDF (fitz) is not installed. PDF metadata extraction will be skipped.")
    print("To install: pip install PyMuPDF")
    fitz = None

def extract_doi_from_text(text):
    """Attempt to find a DOI in text."""
    # A simple regex for DOIs (e.g., 10.1016/j.jfineco.2003.11.001)
    match = re.search(r'(10\.\d{4,9}/[-._;()/:A-Z0-9]+)', text, re.IGNORECASE)
    if match:
        return match.group(1)
    return None

def clean_filename(name):
    """Remove special characters strictly for filenames."""
    return re.sub(r'[^\w\s-]', '', name).strip().replace(' ', '_')

def process_pdf(file_path):
    """
    Process a single PDF. In a real scenario, we might hit the CrossRef API 
    with the extracted DOI to get the Author, Year, and Title.
    """
    if fitz is None:
        return None, "PyMuPDF missing"

    try:
        doc = fitz.open(file_path)
        # Extract from first page
        page = doc.load_page(0)
        text = page.get_text()
        
        doi = extract_doi_from_text(text)
        
        # Metadata from document properties
        meta = doc.metadata
        title = meta.get('title', '')
        author = meta.get('author', '')
        
        doc.close()
        
        # Basic fallback creation if fields are empty
        if not title:
            title = "Unknown_Title"
        if not author:
            author = "Unknown_Author"
            
        clean_author = clean_filename(author.split(',')[0]) # Use first author
        clean_title = clean_filename(title[:50]) # Limit title length
        
        new_name = f"{clean_author}_Title_{clean_title}.pdf"
        if doi:
            # We found a DOI, so maybe mark it
            new_name = f"{clean_author}_DOI_Found.pdf"
            
        return new_name, None

    except Exception as e:
        return None, str(e)

def main():
    print("=== Disorganized PDF File Clean-up Strategy ===")
    
    # User Configuration
    target_dir = input("Enter the directory containing disorganized PDFs: ").strip()
    if not os.path.exists(target_dir):
        print("Directory not found!")
        sys.exit(1)
        
    dest_dir = "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/01_Literature_Review"
    os.makedirs(dest_dir, exist_ok=True)
    
    print(f"Scanning target directory: {target_dir}")
    pdfs = [f for f in os.listdir(target_dir) if f.lower().endswith('.pdf')]
    
    if not pdfs:
        print("No PDFs found in the target directory.")
        return
        
    print(f"Found {len(pdfs)} PDFs. Dry-run started...")
    for pdf in pdfs:
        full_path = os.path.join(target_dir, pdf)
        new_name, error = process_pdf(full_path)
        
        if error:
            print(f"[FAIL] {pdf} -> Error: {error}")
            continue
            
        new_path = os.path.join(dest_dir, new_name)
        print(f"[RENAME proposed] {pdf} -> {new_name}")
        
    print("\n--- Dry run complete ---")
    print("To actually move and rename files, open the script and implement the shutil.move logic.")

if __name__ == "__main__":
    main()
