import os
from pathlib import Path

def main():
    docs_dir = "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/1. Documents"
    output_file = "/Users/mehmetgokhanozdemir/Library/CloudStorage/OneDrive-Kişisel/Akademik_Arastirma/11_Notes_Obsidian/Background_Documents_Index.md"
    
    # Ensure the directory exists
    if not os.path.exists(docs_dir):
        print(f"Error: Directory {docs_dir} not found. Check the path.")
        return

    # Check that Obsidian folder exists
    obsidian_dir = os.path.dirname(output_file)
    if not os.path.exists(obsidian_dir):
        os.makedirs(obsidian_dir, exist_ok=True)
        print(f"Created Obsidian directory at {obsidian_dir}")

    # Generate markdown index
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("# Background Documents Index\n\n")
        f.write("This index maps to the PDFs and references found in `1. Documents` (background knowledge).\n")
        f.write("Links are formatted for Obsidian so you can quickly search and trace citations.\n\n")

        # Walk through the directory and categorize files by directories
        for root, _, files in os.walk(docs_dir):
            if not files:
                continue
                
            relative_path = os.path.relpath(root, docs_dir)
            if relative_path == ".":
                f.write("## Root\n")
            else:
                f.write(f"## {relative_path}\n")

            pdfs = [item for item in files if item.lower().endswith('.pdf')]
            
            if not pdfs:
                f.write("*No PDFs in this directory*.\n\n")
                continue

            for file in pdfs:
                file_path = os.path.join(root, file)
                # Ensure properly URL-encoded path for Obsidian format if needed, 
                # or absolute standard Markdown link format:
                # `[File Name](file:///path/to/file)`
                file_url = file_path.replace(" ", "%20")
                f.write(f"- [{file}](file://{file_url})\n")
                
            f.write("\n")
            
    print(f"Successfully wrote index to {output_file}")

if __name__ == "__main__":
    main()
