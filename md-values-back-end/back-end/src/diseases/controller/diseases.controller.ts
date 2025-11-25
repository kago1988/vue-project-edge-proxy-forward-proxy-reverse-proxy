// src/diseases/diseases.controller.ts
import { Controller, Get, Query } from '@nestjs/common';
import { DiseasesService, Disease } from '../services/diseases.service';

@Controller('diseases')
export class DiseasesController {
  constructor(private readonly diseasesService: DiseasesService) {}

  // GET /diseases
  @Get()
  async getAll(): Promise<Disease[]> {
    return this.diseasesService.getAll();
  }

  // GET /diseases/search?q=lung
  @Get('search')
  async search(@Query('q') q: string): Promise<Disease[]> {
    return this.diseasesService.search(q);
  }
}
