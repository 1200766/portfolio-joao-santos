import { TestBed } from '@angular/core/testing';

import { UtentesService } from './utentes.service';

describe('UtentesService', () => {
  let service: UtentesService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(UtentesService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
