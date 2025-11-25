import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';

// Same Disease interface you already use
export interface Disease {
  name: string;
  code: string;
  abbr?: string;
  category: string;
}

@Injectable({
  providedIn: 'root',
})
export class DiseasesService {
  private readonly BASE_URL = '/api/diseases';  // no back-end port displayed here.

  constructor(private http: HttpClient) {}

  search(term: string): Observable<Disease[]> {
    const params = new HttpParams().set('q', term);
    return this.http.get<Disease[]>(`${this.BASE_URL}/search`, { params });
  }
}
