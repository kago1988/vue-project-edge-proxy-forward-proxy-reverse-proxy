// src/app/app.component.ts

import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet } from '@angular/router';
// 1. Import the standalone component
import { DiseaseSearchComponent } from './components/disease-search/disease-search.component';

@Component({
  selector: 'app-root',
  standalone: true,
  // 2. Add the component to the imports array
  imports: [CommonModule, RouterOutlet, DiseaseSearchComponent], // <-- Add it here
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss'],
})
export class AppComponent {
  title = 'medicalvalues-front-end';
}