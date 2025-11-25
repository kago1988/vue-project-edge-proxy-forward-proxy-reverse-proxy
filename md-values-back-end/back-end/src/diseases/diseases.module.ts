// src/diseases/diseases.module.ts
import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { DiseasesController } from './controller/diseases.controller';
import { DiseasesService } from './services/diseases.service';

@Module({
  imports: [HttpModule],
  controllers: [DiseasesController],
  providers: [DiseasesService],
})
export class DiseasesModule {}
