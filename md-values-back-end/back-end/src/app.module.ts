// src/app.module.ts
import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { DiseasesModule } from './diseases/diseases.module';

@Module({
  imports: [DiseasesModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
