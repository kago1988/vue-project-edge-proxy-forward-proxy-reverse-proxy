// src/app.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { DiseasesModule } from './diseases/diseases.module';

@Module({
  imports: [
    // Load a single .env file in every environment
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env', // always this one file
    }),

    DiseasesModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
