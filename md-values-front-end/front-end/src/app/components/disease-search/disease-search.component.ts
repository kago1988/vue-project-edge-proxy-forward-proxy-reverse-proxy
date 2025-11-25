import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClientModule } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { DiseasesService, Disease } from '../../services/diseases.service';

// Interface for the match with highlighting
interface Match extends Disease {
  highlightedName: string;
  highlightedCode: string;
  highlightedAbbr: string;
}

@Component({
  selector: 'app-disease-search',
  standalone: true,
  imports: [CommonModule, HttpClientModule, FormsModule],
  templateUrl: './disease-search.component.html',
  styleUrls: ['./disease-search.component.scss'],
})
export class DiseaseSearchComponent {
  searchTerm: string = '';
  matches: Match[] = [];
  loading: boolean = false;

  constructor(private diseasesService: DiseasesService) {}

  /**
   * Called on every keystroke from the template.
   */
  onSearchChange(value: string): void {
    this.searchTerm = value;
    this.search();
  }

  /**
   * Main search method – now calls the backend service.
   */
  search(): void {
    const term = this.searchTerm.trim();

    if (!term) {
      this.matches = [];
      return;
    }

    this.loading = true;

    this.diseasesService.search(term).subscribe({
      next: (rawMatches: Disease[]) => {
        this.loading = false;

        this.matches = rawMatches.map((disease) => ({
          ...disease,
          highlightedName: this.highlight(disease.name, term),
          highlightedCode: this.highlight(disease.code, term),
          highlightedAbbr: this.highlight(disease.abbr || '', term),
        }));
      },
      error: (err) => {
        this.loading = false;
        console.error('Error fetching matches:', err);
        this.matches = [];
      },
    });
  }

  /**
   * Replaces search term occurrences with a highlighted span.
   */
  highlight(text: string, term: string): string {
    if (!term) return text;
    const regex = new RegExp(term, 'gi');
    return text.replace(regex, (match) => `<span class="hl">${match}</span>`);
  }
}
