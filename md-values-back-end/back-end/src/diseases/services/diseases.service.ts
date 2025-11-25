// src/diseases/diseases.service.ts
import { Injectable } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';

let DISEASES_URL: string;

if (typeof process.env.DISEASES_URL === 'string' && process.env.DISEASES_URL.trim() !== '') {
  DISEASES_URL = process.env.DISEASES_URL;
} else {
  DISEASES_URL =
    'https://raw.githubusercontent.com/NCI-CBIIT/FHH/master/data/diseases.json';
}

export type Disease = {
  name: string;
  abbr?: string;
  code: string;
  system: string;
  category?: string;
};

@Injectable()
export class DiseasesService {
  private diseases: Disease[] | null = null;

  constructor(private readonly http: HttpService) {}

  // Load and cache diseases from remote JSON
  private async loadDiseases(): Promise<Disease[]> {
    if (this.diseases) {
      return this.diseases;
    }

    const response = await firstValueFrom(this.http.get(DISEASES_URL));
    const raw = response.data as Record<string, Omit<Disease, 'category'>[]>;

    this.diseases = Object.entries(raw).flatMap(([category, items]) =>
      items.map((d) => ({ ...d, category }))
    );

    return this.diseases;
  }

  private findMatches(query: string, list: Disease[]): Disease[] {
    const term = (query ?? '').trim();
    if (!term) return [];

    const regex = new RegExp(term, 'i');

    return list.filter(
      (d) =>
        regex.test(d.name) ||
        regex.test(d.code) ||
        (d.abbr && regex.test(d.abbr)),
    );
  }

  async getAll(): Promise<Disease[]> {
    return this.loadDiseases();
  }

  async search(query: string): Promise<Disease[]> {
    const all = await this.loadDiseases();
    return this.findMatches(query, all);
  }
}
